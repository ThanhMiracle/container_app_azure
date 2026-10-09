# Container App API: products request failed with HTTP 502

Date: 2026-10-08 (Asia/Saigon)  
Status: Resolved and verified through Azure Front Door

## Browser error

The frontend could not load the product list. The browser console reported:

```text
Failed to load resource: the server responded with a status of 502
/api/products/?q=&skip=0&limit=12

Failed to load products 502
```

Request flow:

```text
Browser -> Azure Front Door -> Application Gateway -> Backend Container App
```

## Findings and root causes

Two issues were found and fixed in sequence.

### 1. Backend health probe checked the wrong endpoint

Application Gateway checked the backend at `/` over HTTPS on port 443. The backend returned HTTP 404 because it exposes its health endpoint at `/health`.

Application Gateway reported:

```text
health: Unhealthy
healthProbeLog: Received invalid status code: 404 in the backend server's HTTP response.
As per the health probe configuration, 200-399 is the acceptable status code.
```

The unhealthy backend explains the original gateway 502 response.

### 2. Application Gateway forwarded the `/api` prefix unchanged

After the health probe was corrected, the products request returned HTTP 404 with:

```json
{"detail":"Not Found"}
```

The frontend requested `/api/products/`, but the backend defines `/products/`. Application Gateway selected the correct backend pool but forwarded the original path without removing `/api`.

The same mismatch affected `/api/health`, because the backend endpoint is `/health`.

## Fixes applied

### Backend health probe

Changed the backend probe path from `/` to `/health` in Azure and in [environments/prod/edge.tf](../../environments/prod/edge.tf):

```hcl
backend_probe_path = "/health"
```

Both backend pools then reported `Healthy` with `Success. Received 200 status code`.

### API path rewrite

Added the `backend-api-prefix` rewrite rule set in [modules/application-gateway/main.tf](../../modules/application-gateway/main.tf) and associated it with the `backend-api` path rule.

The rewrite uses:

```text
Condition variable: var_uri_path
Pattern:            ^/api/(.*)$
Replacement path:   /{var_uri_path_1}
Re-evaluate route:  false
```

For example:

```text
Incoming: /api/products/?q=&skip=0&limit=12
Backend:  /products/?q=&skip=0&limit=12
```

Query parameters are preserved. Disabling route re-evaluation keeps the request in the backend API pool after the prefix is removed. The rewrite is scoped to the API path rule; normal frontend requests use the existing frontend route.

The rewrite was applied to the live Application Gateway, which completed the update with provisioning state `Succeeded`.

## Verification results

Requests were tested through the public Front Door endpoint:

```text
https://myapp-prod-fd-thanhdt03-h6b7aeatcrdka2hx.z03.azurefd.net
```

| Request | HTTP status | Response |
| --- | --- | --- |
| `/api/health` | 200 | `{"status":"ok"}` |
| `/api/ready` | 200 | `{"status":"ready"}` |
| `/api/products/?q=&skip=0&limit=12` | 200 | Valid products JSON |

The products response at verification time was:

```json
{"items":[],"total":0,"skip":0,"limit":12,"q":""}
```

The request now succeeds. The empty list means the API returned zero products at the time of the check.

Terraform validation and `git diff --check` passed.

## Commands to recheck

From PowerShell at the repository root:

```powershell
az network application-gateway show-backend-health --resource-group ThanhDT03-Lab --name myapp-prod-appgw --output json

$frontDoorHost = terraform '-chdir=environments/prod' output -raw front_door_hostname
curl.exe -i "https://$frontDoorHost/api/health"
curl.exe -i "https://$frontDoorHost/api/ready"
curl.exe -i "https://$frontDoorHost/api/products/?q=&skip=0&limit=12"
```

Refresh the browser page after the gateway update completes to issue a new products request.
