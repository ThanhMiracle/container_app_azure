variable "name" { type = string }
variable "endpoint_name" { type = string }
variable "resource_group_name" { type = string }
variable "origin_host_name" { type = string }
variable "log_multipart_parser_errors" {
  description = "Set multipart parser rules 200002 and 200003 to Log across this policy instead of anomaly scoring. Other rules and Prevention mode stay enabled."
  type        = bool
  default     = false
  nullable    = false
}

variable "multipart_upload_uri_prefixes" {
  description = "Upload API path prefixes exempted only from multipart parsing rules 200002 and 200003, including all IDs beneath each prefix. Set [] and apply to revoke the exception."
  type        = set(string)
  default     = []
  nullable    = false

  validation {
    condition = length(var.multipart_upload_uri_prefixes) <= 10 && alltrue([
      for prefix in var.multipart_upload_uri_prefixes :
      startswith(prefix, "/") && endswith(prefix, "/") && length(prefix) > 1 && !can(regex("[?*#]", prefix))
    ])
    error_message = "Provide at most 10 API path prefixes starting and ending with /, excluding the root /, wildcards, query strings, and fragments."
  }
}

variable "tags" {
  type = map(string)
  default = {}
}
