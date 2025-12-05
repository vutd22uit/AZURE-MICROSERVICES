# ================================================================
# Terraform Outputs - Azure E-Commerce System
# ================================================================

# ================================================================
# Resource Group
# ================================================================

output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}

# ================================================================
# AKS Outputs
# ================================================================

output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  description = "ID of the AKS cluster"
  value       = azurerm_kubernetes_cluster.aks.id
}

output "aks_kube_config" {
  description = "Kubernetes configuration"
  value       = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive   = true
}

output "aks_host" {
  description = "Kubernetes host endpoint"
  value       = azurerm_kubernetes_cluster.aks.kube_config[0].host
  sensitive   = true
}

# ================================================================
# Container Registry
# ================================================================

output "acr_login_server" {
  description = "ACR login server URL"
  value       = azurerm_container_registry.acr.login_server
}

output "acr_admin_username" {
  description = "ACR admin username"
  value       = azurerm_container_registry.acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "ACR admin password"
  value       = azurerm_container_registry.acr.admin_password
  sensitive   = true
}

# ================================================================
# PostgreSQL Outputs
# ================================================================

output "postgres_server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.postgres.name
}

output "postgres_server_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = azurerm_postgresql_flexible_server.postgres.fqdn
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = azurerm_postgresql_flexible_server_database.authdb.name
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value       = "postgresql://${var.postgres_admin_username}:${var.postgres_admin_password}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.authdb.name}?sslmode=require"
  sensitive   = true
}

# ================================================================
# Cosmos DB Outputs
# ================================================================

output "cosmos_db_endpoint" {
  description = "Cosmos DB endpoint"
  value       = azurerm_cosmosdb_account.cosmos.endpoint
}

output "cosmos_db_primary_key" {
  description = "Cosmos DB primary key"
  value       = azurerm_cosmosdb_account.cosmos.primary_key
  sensitive   = true
}

output "cosmos_db_connection_string" {
  description = "Cosmos DB connection string"
  value       = azurerm_cosmosdb_account.cosmos.connection_strings[0]
  sensitive   = true
}

output "cosmos_db_database_name" {
  description = "Cosmos DB database name"
  value       = azurerm_cosmosdb_sql_database.ordersdb.name
}

# ================================================================
# Application Insights
# ================================================================

output "appinsights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.appinsights.instrumentation_key
  sensitive   = true
}

output "appinsights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.appinsights.connection_string
  sensitive   = true
}

# ================================================================
# Azure Functions
# ================================================================

output "payment_function_url" {
  description = "Payment function URL"
  value       = "https://${azurerm_linux_function_app.payment.default_hostname}/api/process-payment"
}

output "email_function_url" {
  description = "Email function URL"
  value       = "https://${azurerm_linux_function_app.email.default_hostname}/api/send-email"
}

output "payment_function_key" {
  description = "Payment function host key"
  value       = azurerm_linux_function_app.payment.site_credential[0].password
  sensitive   = true
}

# ================================================================
# Synapse Analytics
# ================================================================

output "synapse_workspace_name" {
  description = "Synapse workspace name"
  value       = azurerm_synapse_workspace.synapse.name
}

output "synapse_sql_endpoint" {
  description = "Synapse SQL endpoint"
  value       = azurerm_synapse_workspace.synapse.connectivity_endpoints.sql
}

output "synapse_sql_pool_name" {
  description = "Synapse SQL pool name"
  value       = azurerm_synapse_sql_pool.pool.name
}

output "synapse_connection_string" {
  description = "Synapse connection string"
  value       = "Server=tcp:${azurerm_synapse_workspace.synapse.name}.sql.azuresynapse.net,1433;Database=ecommercedw;User ID=${var.synapse_admin_username};Password=${var.synapse_admin_password};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  sensitive   = true
}

# ================================================================
# Data Factory
# ================================================================

output "data_factory_name" {
  description = "Data Factory name"
  value       = azurerm_data_factory.adf.name
}

output "data_factory_id" {
  description = "Data Factory ID"
  value       = azurerm_data_factory.adf.id
}

# ================================================================
# Power BI Embedded
# ================================================================

output "powerbi_embedded_id" {
  description = "Power BI Embedded capacity ID"
  value       = azurerm_powerbi_embedded.powerbi.id
}

output "powerbi_embedded_name" {
  description = "Power BI Embedded capacity name"
  value       = azurerm_powerbi_embedded.powerbi.name
}

# ================================================================
# Redis Cache (if enabled)
# ================================================================

output "redis_hostname" {
  description = "Redis cache hostname"
  value       = var.enable_redis ? azurerm_redis_cache.redis[0].hostname : null
}

output "redis_primary_key" {
  description = "Redis cache primary key"
  value       = var.enable_redis ? azurerm_redis_cache.redis[0].primary_access_key : null
  sensitive   = true
}

# ================================================================
# Summary
# ================================================================

output "summary" {
  description = "Deployment summary"
  value = {
    resource_group      = azurerm_resource_group.main.name
    location            = azurerm_resource_group.main.location
    aks_cluster         = azurerm_kubernetes_cluster.aks.name
    container_registry  = azurerm_container_registry.acr.login_server
    postgres_server     = azurerm_postgresql_flexible_server.postgres.fqdn
    cosmos_endpoint     = azurerm_cosmosdb_account.cosmos.endpoint
    synapse_workspace   = azurerm_synapse_workspace.synapse.name
    data_factory        = azurerm_data_factory.adf.name
    powerbi_capacity    = azurerm_powerbi_embedded.powerbi.name
    payment_function    = azurerm_linux_function_app.payment.default_hostname
    email_function      = azurerm_linux_function_app.email.default_hostname
  }
}

# ================================================================
# Quick Start Commands
# ================================================================

output "quick_start_commands" {
  description = "Quick start commands for deployment"
  value = <<-EOT
    # Get AKS credentials
    az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.aks.name}

    # Login to ACR
    az acr login --name ${azurerm_container_registry.acr.name}

    # Connect to PostgreSQL
    psql "postgresql://${var.postgres_admin_username}@${azurerm_postgresql_flexible_server.postgres.fqdn}:5432/${azurerm_postgresql_flexible_server_database.authdb.name}?sslmode=require"

    # View Application Insights
    az monitor app-insights component show --app ${azurerm_application_insights.appinsights.name} --resource-group ${azurerm_resource_group.main.name}

    # Pause Synapse SQL Pool (to save costs)
    az synapse sql pool pause --name ${azurerm_synapse_sql_pool.pool.name} --workspace-name ${azurerm_synapse_workspace.synapse.name} --resource-group ${azurerm_resource_group.main.name}

    # Resume Synapse SQL Pool
    az synapse sql pool resume --name ${azurerm_synapse_sql_pool.pool.name} --workspace-name ${azurerm_synapse_workspace.synapse.name} --resource-group ${azurerm_resource_group.main.name}
  EOT
}
