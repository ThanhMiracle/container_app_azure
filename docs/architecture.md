# Terraform deployment flow

```text
Existing RG: ThanhDT03-Lab
        |
        +-- VNet
        |    +-- Application Gateway subnet
        |    +-- Container Apps subnet
        |    +-- PostgreSQL subnet
        |    +-- Private Endpoint subnet
        |
        +-- Log Analytics + Application Insights
        |
        +-- ACR Premium
        |    +-- private endpoint + private DNS
        |    +-- GitHub OIDC publisher identity -> AcrPush
        |    +-- frontend identity -> AcrPull
        |    +-- backend identity  -> AcrPull
        |
        +-- PostgreSQL Flexible Server
        |    +-- private delegated subnet
        |    +-- private DNS
        |    +-- generated administrator password
        |
        +-- Key Vault
        |    +-- private endpoint + private DNS
        |    +-- database-url secret
        |    +-- backend identity -> Key Vault Secrets User
        |
        +-- Storage Account
        |    +-- blob private endpoint + private DNS
        |    +-- backend identity -> Storage Blob Data Contributor
        |
        +-- Internal Container Apps Environment
        |    +-- private DNS for environment default domain
        |    +-- frontend app (placeholder image)
        |    +-- backend app (placeholder image + DATABASE_URL Key Vault reference)
        |
        +-- Application Gateway WAF v2
        |    +-- /       -> frontend
        |    +-- /api/*  -> backend
        |
        +-- Front Door Premium + WAF
             +-- HTTPS public entry point
             +-- origin -> Application Gateway
```

## Ownership boundary

Terraform owns infrastructure and application configuration except the deployed container image.

Future CI/CD owns the image lifecycle:

```text
Build -> Push image to ACR -> az containerapp update --image ...
```

Terraform ignores changes to the image field so the two systems do not fight each other.
