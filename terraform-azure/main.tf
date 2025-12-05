# ================================================================
# Azure E-Commerce Cloud-Native System - Terraform Configuration
# ================================================================
# This configuration creates all Azure resources needed for the project
# - AKS Cluster
# - Azure Database for PostgreSQL
# - Cosmos DB
# - Azure Synapse Analytics
# - Azure Data Factory
# - Power BI Embedded
# - Azure Functions
# - Container Registry
# - Application Insights
# ================================================================

terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# ================================================================
# Resource Group
# ================================================================

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = var.tags
}

# ================================================================
# Azure Kubernetes Service (AKS)
# ================================================================

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${var.project_name}-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "${var.project_name}-aks"
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.aks_node_count
    vm_size             = var.aks_vm_size
    os_disk_size_gb     = 50
    type                = "VirtualMachineScaleSets"
    enable_auto_scaling = true
    min_count           = var.aks_min_nodes
    max_count           = var.aks_max_nodes

    tags = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    network_policy    = "calico"
  }

  tags = var.tags
}

# Grant AKS access to ACR
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

# ================================================================
# Azure Container Registry (ACR)
# ================================================================

resource "azurerm_container_registry" "acr" {
  name                = replace("${var.project_name}acr", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard"
  admin_enabled       = true

  tags = var.tags
}

# ================================================================
# Azure Database for PostgreSQL (Flexible Server)
# ================================================================

resource "azurerm_postgresql_flexible_server" "postgres" {
  name                   = "${var.project_name}-postgres"
  resource_group_name    = azurerm_resource_group.main.name
  location               = azurerm_resource_group.main.location
  version                = "14"
  administrator_login    = var.postgres_admin_username
  administrator_password = var.postgres_admin_password
  storage_mb             = 32768
  sku_name               = "GP_Standard_D2s_v3"
  backup_retention_days  = 7

  tags = var.tags
}

resource "azurerm_postgresql_flexible_server_database" "authdb" {
  name      = "authdb"
  server_id = azurerm_postgresql_flexible_server.postgres.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure" {
  name             = "AllowAllAzureServices"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_all" {
  name             = "AllowAll"
  server_id        = azurerm_postgresql_flexible_server.postgres.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "255.255.255.255"
}

# ================================================================
# Azure Cosmos DB
# ================================================================

resource "azurerm_cosmosdb_account" "cosmos" {
  name                = "${var.project_name}-cosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  enable_free_tier    = var.cosmos_enable_free_tier

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  capabilities {
    name = "EnableServerless"
  }

  tags = var.tags
}

resource "azurerm_cosmosdb_sql_database" "ordersdb" {
  name                = "ordersdb"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.cosmos.name
}

resource "azurerm_cosmosdb_sql_container" "products" {
  name                  = "products"
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.ordersdb.name
  partition_key_path    = "/category"
  partition_key_version = 1

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                  = "orders"
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.ordersdb.name
  partition_key_path    = "/userId"
  partition_key_version = 1

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

resource "azurerm_cosmosdb_sql_container" "cart" {
  name                  = "cart"
  resource_group_name   = azurerm_resource_group.main.name
  account_name          = azurerm_cosmosdb_account.cosmos.name
  database_name         = azurerm_cosmosdb_sql_database.ordersdb.name
  partition_key_path    = "/userId"
  partition_key_version = 1

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
}

# ================================================================
# Storage Account (for Azure Functions)
# ================================================================

resource "azurerm_storage_account" "functions" {
  name                     = replace("${var.project_name}funcstorage", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = var.tags
}

# ================================================================
# Application Insights
# ================================================================

resource "azurerm_log_analytics_workspace" "logs" {
  name                = "${var.project_name}-logs"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = var.tags
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.project_name}-appinsights"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.logs.id
  application_type    = "web"

  tags = var.tags
}

# ================================================================
# Azure Functions - App Service Plan
# ================================================================

resource "azurerm_service_plan" "functions" {
  name                = "${var.project_name}-functions-plan"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption plan

  tags = var.tags
}

# ================================================================
# Azure Functions - Payment Processor
# ================================================================

resource "azurerm_linux_function_app" "payment" {
  name                = "${var.project_name}-payment"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id            = azurerm_service_plan.functions.id

  site_config {
    application_stack {
      node_version = "18"
    }

    application_insights_key               = azurerm_application_insights.appinsights.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.appinsights.connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"       = "node"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "~18"
    "COSMOS_DB_ENDPOINT"             = azurerm_cosmosdb_account.cosmos.endpoint
    "COSMOS_DB_KEY"                  = azurerm_cosmosdb_account.cosmos.primary_key
    "COSMOS_DB_DATABASE"             = azurerm_cosmosdb_sql_database.ordersdb.name
    "EMAIL_FUNCTION_URL"             = "https://${azurerm_linux_function_app.email.default_hostname}/api/send-email"
  }

  tags = var.tags
}

# ================================================================
# Azure Functions - Email Notification
# ================================================================

resource "azurerm_linux_function_app" "email" {
  name                = "${var.project_name}-email"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key
  service_plan_id            = azurerm_service_plan.functions.id

  site_config {
    application_stack {
      node_version = "18"
    }

    application_insights_key               = azurerm_application_insights.appinsights.instrumentation_key
    application_insights_connection_string = azurerm_application_insights.appinsights.connection_string
  }

  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~18"
    "SENDGRID_API_KEY"             = var.sendgrid_api_key
    "FROM_EMAIL"                   = var.from_email
  }

  tags = var.tags
}

# ================================================================
# Azure Synapse Analytics
# ================================================================

resource "azurerm_synapse_workspace" "synapse" {
  name                                 = "${var.project_name}-synapse"
  resource_group_name                  = azurerm_resource_group.main.name
  location                             = azurerm_resource_group.main.location
  storage_data_lake_gen2_filesystem_id = azurerm_storage_data_lake_gen2_filesystem.synapse.id
  sql_administrator_login              = var.synapse_admin_username
  sql_administrator_login_password     = var.synapse_admin_password

  aad_admin {
    login     = var.aad_admin_login
    object_id = var.aad_admin_object_id
    tenant_id = var.aad_admin_tenant_id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Storage for Synapse
resource "azurerm_storage_account" "synapse" {
  name                     = replace("${var.project_name}synapse", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  account_kind             = "StorageV2"
  is_hns_enabled           = true

  tags = var.tags
}

resource "azurerm_storage_data_lake_gen2_filesystem" "synapse" {
  name               = "synapsefilesystem"
  storage_account_id = azurerm_storage_account.synapse.id
}

# Synapse SQL Pool
resource "azurerm_synapse_sql_pool" "pool" {
  name                 = "ecommercedw"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  sku_name             = "DW100c"
  create_mode          = "Default"

  tags = var.tags
}

# Synapse Firewall Rule
resource "azurerm_synapse_firewall_rule" "allow_all" {
  name                 = "AllowAll"
  synapse_workspace_id = azurerm_synapse_workspace.synapse.id
  start_ip_address     = "0.0.0.0"
  end_ip_address       = "255.255.255.255"
}

# ================================================================
# Azure Data Factory
# ================================================================

resource "azurerm_data_factory" "adf" {
  name                = "${var.project_name}-adf"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

# Linked Service - Cosmos DB
resource "azurerm_data_factory_linked_service_cosmosdb" "cosmos" {
  name              = "CosmosDBLinkedService"
  data_factory_id   = azurerm_data_factory.adf.id
  account_endpoint  = azurerm_cosmosdb_account.cosmos.endpoint
  account_key       = azurerm_cosmosdb_account.cosmos.primary_key
  database          = azurerm_cosmosdb_sql_database.ordersdb.name
}

# Linked Service - Synapse (Azure SQL Database type for Synapse SQL Pool)
resource "azurerm_data_factory_linked_service_azure_sql_database" "synapse" {
  name              = "SynapseLinkedService"
  data_factory_id   = azurerm_data_factory.adf.id
  connection_string = "Server=tcp:${azurerm_synapse_workspace.synapse.name}.sql.azuresynapse.net,1433;Database=${azurerm_synapse_sql_pool.pool.name};User ID=${var.synapse_admin_username};Password=${var.synapse_admin_password};Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
}

# ================================================================
# Power BI Embedded
# ================================================================
# Note: Power BI Embedded capacities are created through Azure Portal or PowerShell
# Terraform support is limited. Use Azure Portal to create Power BI Embedded capacity
# or use the azurerm_powerbi_embedded resource if available in your provider version

# Placeholder for Power BI Embedded (create manually via Azure Portal)
# resource "azurerm_powerbi_embedded" "powerbi" {
#   name                = "${var.project_name}-powerbi"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   sku                 = var.powerbi_sku
#   administrators      = [var.powerbi_admin_email]
#   tags                = var.tags
# }

# Alternative: Create via Azure CLI after Terraform apply
# az powerbi embedded-capacity create \
#   --resource-group ecommerce-cloud-rg \
#   --name ecommerce-cloud-powerbi \
#   --location "Southeast Asia" \
#   --sku-name A1 \
#   --sku-tier PBIE_Azure \
#   --administration-members "your-email@example.com"

# ================================================================
# Azure Redis Cache (optional - for caching)
# ================================================================

resource "azurerm_redis_cache" "redis" {
  count               = var.enable_redis ? 1 : 0
  name                = "${var.project_name}-redis"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  capacity            = 1
  family              = "C"
  sku_name            = "Standard"
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
  }

  tags = var.tags
}
