# Azure production-style Terraform repo

This repository provisions the Azure platform shown in the supplied architecture while keeping the practical constraints for this project:

- Existing Resource Group only: `ThanhDT03-Lab`
- Local Terraform state only; there is deliberately **no remote backend**
- Azure Container Apps are created by Terraform **before** application CI/CD exists
- Container Apps initially run a public placeholder image
- Later CI/CD owns only the deployed application image and Terraform ignores image drift
- GitHub Actions authenticates to Azure with OIDC through a dedicated user-assigned managed identity that has `AcrPush`
- Frontend and backend Container Apps use separate managed identities with `AcrPull`
- PostgreSQL `DATABASE_URL` is stored in Azure Key Vault
- Backend Container App reads `DATABASE_URL` from Key Vault through a Key Vault-backed Container Apps secret
- ACR admin credentials are disabled
- No AKS, Bastion, Azure OpenAI, Sentinel, or Resource Group module

## What is deployed

Core networking and edge:

- Virtual Network
- Application Gateway subnet
- Container Apps infrastructure subnet (`10.20.8.0/21`; sized for current Azure Container Apps environment requirements)
- PostgreSQL delegated subnet
- Private Endpoint subnet
- Application Gateway WAF v2
- Azure Front Door Premium + WAF

Application platform:

- Azure Container Registry Premium
- Internal Azure Container Apps Environment
- Frontend Container App
- Backend Container App
- Frontend/backend user-assigned managed identities
- GitHub OIDC publishing identity with `AcrPush`

Data and platform services:

- PostgreSQL Flexible Server + database
- Azure Key Vault
- Storage Account
- Optional Service Bus Premium namespace + queue
- Private Endpoints for ACR, Key Vault and Blob Storage
- Private DNS zones for private endpoints, PostgreSQL and the internal Container Apps Environment

Monitoring:

- Log Analytics Workspace
- Application Insights
- Container Apps Environment logs sent to Log Analytics
- Application Insights connection string injected into both apps

## Important design choices

### 1. Container Apps are created before your application images exist

Terraform initially deploys:

```text
mcr.microsoft.com/azuredocs/containerapps-helloworld:latest
```

The Container App module contains:

```hcl
lifecycle {
  ignore_changes = [
    template[0].container[0].image
  ]
}
```

Your future GitHub Actions workflow can therefore update the image without a later `terraform apply` reverting it back to the placeholder.

### 2. GitHub push identity is separate from runtime identities

```text
GitHub Actions --OIDC--> GitHub ACR publisher identity --AcrPush--> ACR

Frontend identity --AcrPull--> ACR
Backend identity  --AcrPull--> ACR
```

No client secret is created for GitHub Actions.

### 3. Database URL is stored in Key Vault

Terraform generates the PostgreSQL administrator password, builds a URL in this shape:

```text
postgresql://USER:PASSWORD@HOST:5432/DATABASE?sslmode=require
```

and stores it as the Key Vault secret:

```text
database-url
```

The backend app receives:

```text
DATABASE_URL
```

through a Key Vault reference. The connection string is not hardcoded in the Container App configuration.

> Terraform state contains values used to create secrets, including the generated PostgreSQL password and the database URL. Because this project intentionally uses local state, protect the local `.tfstate` file and never commit it.

### 4. ACR has a private endpoint but public network access is left enabled

This lets Container Apps resolve ACR privately from the VNet while still allowing a normal GitHub-hosted runner to push images later. Authentication still uses OIDC/RBAC and ACR admin credentials are disabled.

If you later disable ACR public network access, use a self-hosted/private-networked GitHub runner that can reach the private endpoint.

### 5. Key Vault bootstrap network access

Key Vault has a private endpoint, but its network ACL defaults to `Allow` in `terraform.tfvars`. This is intentional so Terraform running from your Windows/WSL workstation can create and refresh the `database-url` secret without the 403 data-plane problem you encountered before.

After you have a private Terraform execution path, change:

```hcl
key_vault_network_default_action = "Deny"
```

and supply allowed IP ranges if necessary.

### 6. Application Gateway origin uses HTTP from Front Door for bootstrap

Front Door redirects clients to HTTPS, but its origin connection to Application Gateway is HTTP on port 80. The Application Gateway subnet NSG only allows inbound port 80 from the `AzureFrontDoor.Backend` service tag plus required Azure gateway management traffic.

For full end-to-end TLS, add a custom domain/certificate to Application Gateway and switch the Front Door origin protocol to HTTPS.

## Prerequisites

- Terraform 1.8+
- Azure CLI logged into the correct tenant/subscription
- Permission to create resources and role assignments inside `ThanhDT03-Lab`
- The existing Resource Group `ThanhDT03-Lab`

No Resource Group is created by this repository.

## Configure

Edit:

```text
environments/prod/terraform.tfvars
```

The included file already uses:

```hcl
resource_group_name = "ThanhDT03-Lab"
location            = "japanwest"
```

Change the GitHub OIDC subject if your application repository is different:

```hcl
github_oidc_subjects = {
  main = "repo:ThanhMiracle/docker:ref:refs/heads/main"
}
```

For GitHub Environments you can instead use a subject such as:

```text
repo:OWNER/REPO:environment:production
```

## Deploy

From PowerShell or WSL:

```bash
cd environments/prod
$env:TF_VAR_postgres_administrator_password = "YourStrongPasswordHere"
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

State remains local in `environments/prod/terraform.tfstate`.

## Useful outputs for CI/CD later

After apply:

```bash
terraform output github_acr_push_client_id
terraform output tenant_id
terraform output subscription_id
terraform output acr_login_server
terraform output frontend_container_app_name
terraform output backend_container_app_name
```

Those outputs are enough to wire the future GitHub Actions OIDC login and image deployment. No workflow is included yet.

## Cost note

`deploy_service_bus = false` by default because private networking for Service Bus uses the Premium tier and can be expensive. The reusable module is included and can be enabled when your application actually needs asynchronous queues.

Azure Firewall, Defender for Cloud pricing configuration, Azure Policy, Management Groups and subscription-level governance are intentionally not created here because they are subscription-scope concerns and this project is designed to work with Resource Group-level ownership.

