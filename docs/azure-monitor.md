# Azure Monitor

The production environment uses the existing Log Analytics workspace
`myapp-prod-law` and workspace-based Application Insights `myapp-prod-appi`.
The `azure-monitor` module adds diagnostic log collection, metric alerts,
Resource Health notifications, and public HTTPS availability tests.

## Notifications and thresholds

`monitor_alert_email_addresses` in `environments/prod/terraform.tfvars` sends
alerts to `dtthanh2909@gmail.com`. Email receivers use the common alert schema.
Metric alerts automatically resolve after their conditions clear.

| Alert | Initial trigger | Window | Severity |
| --- | --- | --- | --- |
| Frontend/backend replicas | Maximum replica count below the app's configured minimum | 5 minutes | 1 |
| Frontend/backend HTTP errors | At least 10 HTTP 5xx responses | 5 minutes | 2 |
| Gateway backend health | Average unhealthy host count greater than zero | 5 minutes | 1 |
| Gateway failed requests | At least 20 failures | 5 minutes | 2 |
| PostgreSQL CPU | Average greater than 80% | 15 minutes | 2 |
| PostgreSQL memory | Average greater than 85% | 15 minutes | 2 |
| PostgreSQL storage | Average greater than 80% | 5 minutes | 1 |
| Front Door origin health | Average successful health probes below 90% | 5 minutes | 1 |
| Front Door HTTP errors | Average HTTP 5xx percentage greater than 5% | 5 minutes | 2 |
| Public frontend/backend availability | At least 3 test locations fail | 5 minutes | 1 |
| Resource Health | Azure reports Degraded or Unavailable within the resource group | Event driven | Activity alert |

Metric alerts are evaluated every minute. The replica alert is designed for the
current Single revision mode; it checks the maximum over the time window to
avoid alerting on a short rolling deployment transition. A missing metric sample
is not proof that an app is healthy; public availability tests also check access
through Front Door, Application Gateway, and the app ingress.

Tune traffic-dependent thresholds after observing normal activity:

```hcl
monitor_thresholds = {
  app_http_5xx_count          = 10
  gateway_failed_requests    = 20
  postgres_cpu_percent       = 80
  postgres_memory_percent    = 85
  postgres_storage_percent   = 80
  front_door_origin_health   = 90
  front_door_http_5xx_percent = 5
}
```

`monitor_alerts_enabled = false` disables alert evaluation/notifications and
availability execution while retaining diagnostic logs. Set
`monitor_availability_tests_enabled = false` to remove only Standard tests and
their alert rules. Empty `monitor_alert_email_addresses` retains portal alerts
without email recipients.

## Logs and metrics

All currently supported log categories are discovered from Azure and sent to
the workspace for Application Gateway, Front Door, PostgreSQL, Key Vault, Blob
Storage, and ACR. Service Bus is included only when `deploy_service_bus = true`.
These diagnostics use the `AzureDiagnostics` table for compatibility across
services. Review new categories and ingestion volume when Azure adds categories.
PostgreSQL logging parameters determine which database events are actually emitted.

Container Apps console/system logs already go directly to the workspace through
the environment. Application Insights is already connected to the workspace;
the module does not duplicate either log stream. Platform metrics are collected
automatically by Azure Monitor and used directly by alerts; diagnostics do not
copy those metrics into the workspace.

The workspace retention is 30 days. Log ingestion, retained volume, metric
alert time series, and Standard availability executions can incur charges.
Review usage in Azure Monitor and Azure Cost Management after deployment.

The Application Insights connection string is injected into the apps, but
request traces, dependencies, and exceptions require an Application Insights or
Azure Monitor OpenTelemetry SDK in the actual application code. Injecting the
connection string alone does not instrument the application.

## Public availability

Standard tests check the public Front Door URLs `/` and `/api/health` every five
minutes from Japan East, Southeast Asia, East Asia, West Europe, and East US.
They require HTTP 200, validate TLS, follow redirects, retry failures, and avoid
downloading page dependencies. The backend app must expose `/health`; gateway
rewriting turns `/api/health` into that backend path. WAF rules must allow these
requests; a blocked test is reported as unavailable.

Standard tests need no application SDK and supplement platform health metrics.
Their success verifies those endpoints, not every application transaction or
database dependency. Make the backend readiness endpoint check critical
dependencies if that is required for your availability objective.

## Deploy and verify

Run a fresh plan from the repository root with the usual required secret
variables available. Review it before applying:

```powershell
terraform -chdir=environments/prod init
terraform -chdir=environments/prod validate
terraform -chdir=environments/prod plan '-out=azure-monitor.tfplan'
terraform -chdir=environments/prod apply azure-monitor.tfplan
```

Open Azure Monitor > Alerts to inspect alert rules and active incidents.
Open Application Insights > Availability for frontend/backend test results.
Open Log Analytics > Logs for collected platform and app logs. Data and
availability test configuration can take several minutes to appear.

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(1h)
| project TimeGenerated, ContainerAppName_s, Log_s
| order by TimeGenerated desc
```

```kusto
AzureDiagnostics
| where TimeGenerated > ago(1h)
| summarize Events=count() by ResourceProvider, Category
| order by Events desc
```

Terraform exports workspace/component IDs, the action group ID, metric alert
IDs, availability test/alert IDs, and the Resource Health alert ID. Configuration
tests use mock providers and do not contact Azure:

```powershell
terraform -chdir=modules/azure-monitor init -backend=false
terraform -chdir=modules/azure-monitor test
```

References: [Container Apps metrics](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/supported-metrics/microsoft-app-containerapps-metrics),
[diagnostic settings](https://learn.microsoft.com/en-us/azure/azure-monitor/data-collection/diagnostic-settings),
and [Standard availability tests](https://learn.microsoft.com/en-us/azure/azure-monitor/app/availability).
