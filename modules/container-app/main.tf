resource "azurerm_container_app" "this" {
  name                         = var.name
  container_app_environment_id = var.environment_id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  dynamic "registry" {
    for_each = var.registry_server == null ? [] : [1]
    content {
      server   = var.registry_server
      identity = var.registry_identity_id
    }
  }

  dynamic "secret" {
    for_each = var.key_vault_secrets
    content {
      name                = secret.key
      key_vault_secret_id = secret.value.key_vault_secret_id
      identity            = secret.value.identity
    }
  }

  template {
    min_replicas = var.min_replicas
    max_replicas = var.max_replicas

    container {
      name   = var.container_name
      image  = var.image
      cpu    = var.cpu
      memory = var.memory

      startup_probe {
        transport               = var.health_probe_paths.startup == null ? "TCP" : "HTTP"
        port                    = var.container_port
        path                    = var.health_probe_paths.startup
        initial_delay           = 1
        interval_seconds        = 1
        timeout                 = 3
        failure_count_threshold = 240
      }

      readiness_probe {
        transport               = var.health_probe_paths.readiness == null ? "TCP" : "HTTP"
        port                    = var.container_port
        path                    = var.health_probe_paths.readiness
        initial_delay           = 3
        interval_seconds        = 5
        timeout                 = 3
        failure_count_threshold = 3
        success_count_threshold = 1
      }

      liveness_probe {
        transport               = var.health_probe_paths.liveness == null ? "TCP" : "HTTP"
        port                    = var.container_port
        path                    = var.health_probe_paths.liveness
        initial_delay           = 10
        interval_seconds        = 10
        timeout                 = 3
        failure_count_threshold = 3
      }

      dynamic "env" {
        for_each = var.environment_variables
        content {
          name  = env.key
          value = env.value
        }
      }

      dynamic "env" {
        for_each = var.secret_environment_variables
        content {
          name        = env.key
          secret_name = env.value
        }
      }
    }
  }

  ingress {
    external_enabled = var.external_enabled
    target_port      = var.container_port
    transport        = "auto"

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }

  lifecycle {
    precondition {
      condition = (
        var.min_replicas >= 0 && floor(var.min_replicas) == var.min_replicas &&
        var.max_replicas >= 1 && floor(var.max_replicas) == var.max_replicas &&
        var.max_replicas >= var.min_replicas
      )
      error_message = "Replica counts must be integers, minimum >= 0, maximum >= 1, and maximum >= minimum."
    }

    ignore_changes = [
      template[0].container[0].image
    ]
  }
}
