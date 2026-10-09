# Azure production-style Terraform repo

This repository provisions the Azure platform shown in the supplied architecture while keeping the practical constraints for this project:

- Existing Resource Group only: `ThanhDT03-Lab`
- Local Terraform state only; there is deliberately **no remote backend**
- Azure Container Apps are created by Terraform **before** application CI/CD exists
- Container Apps initially run a public placeholder image
- Later CI/CD owns only the deployed application image and Terraform ignores image drift
- GitHub Actions uses separate OIDC identities: the publisher has `AcrPush` on ACR, and the deployer has `Container Apps Contributor` on the frontend/backend apps
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
- Separate GitHub OIDC deployment identity with app-scoped deployment permissions

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

### 2. GitHub publishing, deployment, and runtime identities are separate

```text
GitHub Actions --OIDC--> GitHub ACR publisher identity --AcrPush--> ACR
GitHub Actions --OIDC--> GitHub Container App deployer identity --Container Apps Contributor--> Frontend/backend apps

Frontend identity --AcrPull--> ACR
Backend identity  --AcrPull--> ACR
```

The deployer has no ACR push permission, and the publisher has no Container App deployment permission. Both identities trust the repository subjects configured in `github_oidc_subjects`. No client secret is created for GitHub Actions.

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
  master = "repo:Dev-MT10-SI@330316027/VNN-Agent-orchestrator@1374089373:ref:refs/heads/master"
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
# JWT signing secret
$env:TF_VAR_jwt_secret = "YourJWTSecretHere"

# SMTP password
$env:TF_VAR_smtp_password = "YourSMTPPasswordHere"
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
terraform output github_container_app_deploy_client_id
terraform output tenant_id
terraform output subscription_id
terraform output acr_login_server
terraform output frontend_container_app_name
terraform output backend_container_app_name
```

Use `github_acr_push_client_id` for image publishing and `github_container_app_deploy_client_id` for app deployment. The existing `AZURE_BUILD_CLIENT_ID` repository variable continues to identify the ACR publisher.

### Deploy an existing image from GitHub Actions

In the application repository, currently `Dev-MT10-SI/VNN-Agent-orchestrator`, configure the Container App deployment job to authenticate using the separate deployment identity. Run the job on `master` to match its federated credential. The existing AKS workflow uses different settings and must be updated separately if you want to migrate it to Container Apps.

In the application repository's **Settings > Secrets and variables > Actions**, configure:

| Kind | GitHub name | Terraform output |
| --- | --- | --- |
| Secret | `AZURE_CONTAINER_APP_DEPLOY_CLIENT_ID` | `github_container_app_deploy_client_id` |
| Secret | `AZURE_TENANT_ID` | `tenant_id` |
| Secret | `AZURE_SUBSCRIPTION_ID` | `subscription_id` |
| Variable | `RESOURCE_GROUP` | `resource_group_name` |
| Variable | `FRONTEND_CONTAINER_APP_NAME` | `frontend_container_app_name` |
| Variable | `BACKEND_CONTAINER_APP_NAME` | `backend_container_app_name` |
| Variable | `ACR_LOGIN_SERVER` | `acr_login_server` |

Read values with `terraform output -raw OUTPUT_NAME` from `environments/prod`. No Azure client secret is needed.

The deployment job needs `permissions: { id-token: write, contents: read }` and this login step:

```yaml
- name: Log in using the Container App deployment identity
  uses: azure/login@v3
  with:
    client-id: ${{ secrets.AZURE_CONTAINER_APP_DEPLOY_CLIENT_ID }}
    tenant-id: ${{ secrets.AZURE_TENANT_ID }}
    subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
```

After login, run `az containerapp update --resource-group "$RESOURCE_GROUP" --name "$CONTAINER_APP_NAME" --image "$IMAGE_TO_DEPLOY"`. Supply an existing full ACR image reference, such as `myappprodacrthanhdt03.azurecr.io/backend:COMMIT_SHA`. Use a unique tag or digest for each deployment.

Do not add a GitHub `environment:` to the deployment job without also configuring a matching environment subject in `github_oidc_subjects`.

## Cost note

`deploy_service_bus = false` by default because private networking for Service Bus uses the Premium tier and can be expensive. The reusable module is included and can be enabled when your application actually needs asynchronous queues.

Azure Firewall, Defender for Cloud pricing configuration, Azure Policy, Management Groups and subscription-level governance are intentionally not created here because they are subscription-scope concerns and this project is designed to work with Resource Group-level ownership.
