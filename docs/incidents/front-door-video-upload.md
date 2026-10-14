# Video review upload blocked by Front Door WAF

Date: 2026-10-14 (Asia/Saigon)

Status: Resolved for the reported video upload. The user confirms that video upload now works. Matching read-only logs show rules 200002 and 200003 with action Log at 16:22:06 Asia/Saigon, followed by the same request returning HTTP 201 at 16:22:07. Its recorded request size was 2,275,801 bytes. Application Gateway was not evidenced as the blocking component.

## Problem

A review submission containing a 2 MB video fails when sent to:

```text
POST /api/products/1/reviews
```

Earlier Azure logs confirmed that Front Door's Web Application Firewall (WAF) blocked requests to this endpoint during multipart request-body parsing. Those requests were stopped before reaching Application Gateway and the backend.

The confirmed failure is WAF rejecting the upload request. The available evidence does not establish whether the multipart data is malformed or whether the WAF parser is producing a false positive for a legitimate upload.

## Evidence

The earlier failed requests shared a tracking reference across these Front Door WAF log entries:

| Rule | Logged action | Meaning |
| --- | --- | --- |
| `Microsoft_DefaultRuleSet-2.1-General-200002` | `AnomalyScoring` | Failed to parse the request body. |
| `Microsoft_DefaultRuleSet-2.1-General-200003` | `AnomalyScoring` | Multipart request body failed strict validation. |
| `Microsoft_DefaultRuleSet-2.1-BLOCKING-EVALUATION-949110` | `Block` | The request's anomaly score reached the blocking threshold. |

The observed policy, `myappprodafdwaf`, used Microsoft Default Rule Set 2.1 in Prevention mode with body inspection enabled and no managed-rule overrides or exceptions at the time it was inspected.

Rules `200002` and `200003` are Critical rules, each contributing 5 points. The blocking threshold is 5, so either match can cause a block. Rule `949110` enforces the accumulated score; it is not the original parsing failure. See [Microsoft's Front Door managed-rule documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-drs).

The deployed frontend was inspected earlier. It constructs a browser `FormData` body, includes the selected files, and lets the browser generate the multipart `Content-Type` and boundary. No manual multipart header was found in that review submission code. This does not verify the exact bytes of the failing request.

## Why 2 MB does not establish a size-limit problem

Front Door's documented WAF body and file inspection limit is 128 KB. Front Door supports larger uploads; its inspection limit and upload capacity are separate limits. The observed parsing messages do not prove that a 2 MB video exceeds an upload limit. See [Front Door service limits](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/azure-subscription-service-limits#azure-front-door-standard-and-premium-service-limits).

## Earlier URI exception deployed by the user

The first deployed configuration contained:

```hcl
front_door_upload_uri_prefixes = ["/api/products/"]
```

The exception used `RequestUri` with the `StartsWith` operator, intended to cover review uploads for every current and future product ID under `/api/products/`, without listing individual products or videos. The continued parsing-rule matches show that this exception did not stop the observed blocks. The precise reason it did not take effect for these rules has not been established; the logged full URL alone does not prove the input used by the exception matcher.

That exception was scoped to the `General` group and only rules `200002` and `200003`. Prevention mode, body inspection, rule `949110`, and the other managed rules remained configured. The prefix covered other product API requests beneath `/api/products/` as well as review requests.

Azure supports URI-based, rule-specific exceptions. See [Front Door WAF exception configuration](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/front-door-exceptions).

The installed AzureRM 4.81 provider does not expose these exceptions, so the code adds the Azure AzAPI provider and an `azapi_update_resource` targeting the existing policy's exception list. The API payload uses version `2025-11-01`, as described in [the Front Door policy API](https://learn.microsoft.com/en-us/rest/api/frontdoorservice/webapplicationfirewall/policies/create-or-update?view=rest-frontdoorservice-webapplicationfirewall-2025-11-01).

Relevant files:

- [Exception resource](../../modules/front-door/upload-exceptions.tf)
- [Front Door module inputs](../../modules/front-door/variables.tf)
- [Module provider requirements](../../modules/front-door/versions.tf)
- [Production module wiring](../../environments/prod/edge.tf)
- [Production inputs](../../environments/prod/variables.tf)
- [Production values](../../environments/prod/terraform.tfvars)
- [Production provider requirements](../../environments/prod/versions.tf)
- [Production provider configuration](../../environments/prod/providers.tf)

The exception resource is configured to reapply after an AzureRM policy update, which may otherwise omit the newer exception property. To revoke the configured exceptions, set `front_door_upload_uri_prefixes = []` and apply that change. Deleting an AzAPI update resource alone does not revert the Azure properties it updated.

## Latest 403 and remaining checks

The latest browser screenshot shows the same POST endpoint returning HTTP 403. A browser status alone cannot identify the responsible WAF rule, prove that the exception is active, or establish that the backend received the request.

No deployment commands were run by the assistant after the user's instruction to edit code only. The user confirms separately running Terraform init and apply. The continued 403 must therefore be investigated using the deployed policy settings and the latest request's logs; it cannot be explained solely by the assistant having made code edits.

The user subsequently authorized read-only Azure CLI commands for diagnosis. These checks confirmed:

- The live policy contains `RequestUri`, `StartsWith`, and `/api/products/`, scoped to General rules `200002` and `200003` in DRS 2.1.
- The Front Door security policy references this same WAF policy and the application's active endpoint.
- Azure reports the WAF policy provisioning state as `Succeeded`.
- The policy update succeeded at 2026-10-14 08:47:56 UTC, or **15:47:56 Asia/Saigon**.
- The supplied tracking reference corresponds to a blocked request at **15:48:07**, only 11 seconds later.
- The latest retrieved upload failure occurred at **15:56:29**. It still matched `200002` and `200003`, followed by `949110` with action `Block` at Front Door. No matching Application Gateway records were returned by the scoped query.

The deployed settings are present, but their availability at every edge location has not been verified. [Microsoft's WAF FAQ](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-faq) says most WAF policy deployments finish in less than 20 minutes and take effect when updates complete across edge locations. Both observed failures occurred within that period. Propagation delay is a plausible explanation, not a proven root cause of the continued failure.

The user retried after the suggested propagation window. Read-only logs show two fresh failures at **16:08:12** and **16:08:17 Asia/Saigon**, still caused by the same parsing rules and final anomaly-score block. The latest tracking reference is:

```text
20261014T090817Z-1585997d9d6f5zpxhC1HK108ag00000001u0000000005pzb
```

Waiting did not resolve these observed failures. A successful control-plane update is therefore insufficient evidence that this URI exception prevents the parsing checks from blocking the upload.

## Current Terraform fallback: log only the two parsing rules

The production configuration has been changed to:

```hcl
front_door_upload_uri_prefixes = []
front_door_log_multipart_parser_errors = true
```

With this explicit opt-in, the Front Door module creates a `General` managed-rule override containing only:

| Rule | Configured action | Enabled |
| --- | --- | --- |
| `200002` | `Log` | `true` |
| `200003` | `Log` | `true` |

These matches should then be logged instead of adding anomaly scores. The policy remains in Prevention mode and retains its Block action for the managed ruleset's anomaly threshold. Rule `949110` and all other managed rules retain their configured enforcement behavior. See [Microsoft's WAF tuning guidance](https://learn.microsoft.com/en-us/azure/web-application-firewall/afds/waf-front-door-tuning).

**Scope:** This fallback applies to the entire associated WAF policy, not only `/api/products/` or video files. It relaxes enforcement of these two multipart parsing checks across all protected routes. It avoids maintaining product-specific paths and covers future upload routes, but application validation and authentication must still reject invalid uploads.

The module and production input defaults are `false`; only this production configuration explicitly enables the fallback. Setting the input back to `false` and applying removes the Log overrides. Applying the empty URI prefix set clears the previous exception list without removing its AzAPI update resource from state.

The new code changes are in:

- [Managed-rule overrides](../../modules/front-door/main.tf)
- [Module flag](../../modules/front-door/variables.tf)
- [Production flag](../../environments/prod/variables.tf)
- [Production wiring](../../environments/prod/edge.tf)
- [Production configuration](../../environments/prod/terraform.tfvars)

The assistant edited the code only and did not run Terraform validation, plan, or apply for this fallback. No Azure settings were modified during the authorized read-only investigation. A subsequent read-only inspection confirmed the live General overrides with action Log and enabled state Enabled for both rules. Azure activity logs record the latest successful policy update at **16:15:53 Asia/Saigon**, consistent with the user deploying the fallback separately.

The last observed Front Door parsing-rule block occurred at **16:16:35**, only 42 seconds after this new update. Its tracking reference is `20261014T091635Z-156c4564d44246qshC1HKG0x1w00000011n000000000m735`. The successful request at **16:22:07** subsequently established that the new Log actions had taken effect at the edge handling that upload. This explains why retries shortly after apply still failed before a later retry succeeded.

## Confirmed resolution

The user reported that video upload now works. Read-only Front Door logs independently confirmed this request:

```text
20261014T092206Z-17868f94dd9wspcxhC1SG1d5k80000000qx0000000003c0q
```

| Time (Asia/Saigon, 2026-10-14) | Event |
| --- | --- |
| 16:15:53 | WAF policy update succeeded in Azure. |
| 16:16:35 | An earlier edge request still logged AnomalyScoring for the two parsing rules and returned 403. |
| 16:22:06 | Both parsing rules matched the successful request with action Log. |
| 16:22:07 | The matching POST returned HTTP 201 Created; recorded request size was 2,275,801 bytes, approximately 2.3 MB including request overhead. |

The upload was not fixed by increasing a file-size limit or disabling the entire WAF. The two parsing checks changed from adding blocking anomaly scores to recording log entries. Once that policy took effect at the serving edge, the request could reach the application and be accepted. The exact reason the parser flags this multipart content remains unproven; changing the rule actions resolves the observed blocking behavior rather than repairing the parser.

The override applies across the policy, so it does not require individual product IDs or video paths. Other managed rules remain enabled, and Prevention mode remains configured. Separate uploads can still be rejected by other WAF rules or application validation.

## Verification checklist

After reviewing and deploying the fallback:

1. Confirm the apply updated the Front Door WAF managed-rule overrides and cleared the old exception list through its AzAPI update resource.
2. Inspect the live policy: General rules `200002` and `200003` must be enabled with action `Log`; the policy must remain in Prevention mode with the managed ruleset's Block action.
3. Allow edge propagation, retry a representative upload, and correlate it with fresh Front Door log entries using its tracking reference.
4. If rule `949110` still blocks a request, inspect every scoring rule for that reference. A different rule may still accumulate enough points to block it.
5. If Front Door forwards the request, inspect Application Gateway WAF and backend logs. They can independently reject an upload, so the latest rule or application error must guide any further change.

## Latest request tracking reference

The user supplied this reference for the continued failure:

```text
20261014T084807Z-16db9f99f4dht88xhC1SG109qs0000001ve00000000005e4
```

Its timestamp is 2026-10-14 08:48:07 UTC, or 15:48:07 in Asia/Saigon. This identifies a request; it is not a WAF rule ID and does not reveal the blocking cause by itself.

In the `myapp-prod-law` Log Analytics workspace, open Logs and use the following query to retrieve the matching Front Door records. The assistant has now retrieved this request's records through the read-only resource-scoped Logs API; they confirmed the same multipart parsing rules and final block.

```kusto
AzureDiagnostics
| where TimeGenerated between (datetime(2026-10-14T08:43:00Z) .. datetime(2026-10-14T08:53:00Z))
| where trackingReference_s == "20261014T084807Z-16db9f99f4dht88xhC1SG109qs0000001ve00000000005e4"
| project TimeGenerated, Category,
    Rule = tostring(column_ifexists("ruleName_s", "")),
    Action = tostring(column_ifexists("action_s", "")),
    Message = tostring(column_ifexists("message_s", "")),
    DetailsMessage = tostring(column_ifexists("details_msg_s", ""))
| order by TimeGenerated asc
```

If the WAF rows still show `200002` and `200003` with anomaly scoring followed by `949110` with Block, the upload is still being blocked by the original parsing checks and the deployed exception must be inspected. If different rules appear, those rules require separate investigation. If no records appear, verify diagnostic collection, ingestion, and the query time range before concluding that Front Door allowed the request.

## Application Gateway WAF inspection

Read-only checks on 2026-10-14 confirmed that `myapp-prod-appgw` uses `myapp-prod-appgw-waf` at gateway scope. There are no listener-level or path-level WAF policy overrides for the API route.

| Setting | Live value |
| --- | --- |
| Policy state | Enabled |
| Mode | Prevention |
| Managed ruleset | OWASP 3.2 |
| Request body inspection | Enabled |
| Inspection limit | 128 KB |
| Maximum non-file request body | 128 KB, enforcement enabled |
| Configured file upload limit | 100 MB |
| File upload size enforcement | Disabled |
| Custom rules / managed-rule overrides | None |

For properly recognized multipart files, the non-file request body limit excludes uploaded file content. File recognition requires `multipart/form-data` and a filename in the file part. A 2 MB file therefore does not automatically exceed this gateway's 128 KB non-file body limit. See [Application Gateway WAF size-limit documentation](https://learn.microsoft.com/en-us/azure/web-application-firewall/ag/application-gateway-waf-request-size-limits).

For `/products/1/reviews` and its original `/api/products/1/reviews` URI, the checked 24-hour logs contained 24 GET requests returning 200 and four POST requests returning 201, with no Application Gateway WAF entries for that endpoint. The latest successful POST was at **16:17:14 Asia/Saigon**. Its Front Door request-size field was 32,884 bytes, so it does not verify the user's 2 MB video upload.

The latest retrieved failure at 16:16:35 was a Front Door WAF block from rules `200002`, `200003`, and `949110`. Application Gateway is not evidenced as the blocking component for these failed uploads. No changes were made to its policy or Terraform configuration.

## Acceptance criteria

- A representative 2 MB video review upload succeeds through the public Front Door hostname.
- The backend accepts the review and stores the attachment successfully.
- Review uploads work for another product ID without editing Terraform again.
- The two parsing rules no longer cause the expected upload to be blocked, while the other managed protections remain active.

The reported video upload, HTTP 201 response, and Log actions for both parsing rules are now confirmed. A separate product ID and a direct inspection of the stored blob were not exercised during this read-only verification.
