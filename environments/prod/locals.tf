locals {
  prefix = "${var.project_name}-${var.environment}"

  tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
    },
    var.tags
  )
  frontend_public_url = "https://${module.front_door.endpoint_hostname}"
  database_url        = "postgresql://${var.postgres_admin_username}:${module.postgresql.admin_password}@${module.postgresql.fqdn}:5432/${var.postgres_database_name}?sslmode=require"
}
