# ================================================================
# Terraform Variables - Azure E-Commerce System
# ================================================================

# ================================================================
# General Variables
# ================================================================

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "ecommerce-cloud"
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
  default     = "ecommerce-cloud-rg"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "Southeast Asia"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "E-Commerce Cloud Native"
    Environment = "Production"
    ManagedBy   = "Terraform"
    Purpose     = "Graduation Project"
  }
}

# ================================================================
# AKS Variables
# ================================================================

variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.27.7"
}

variable "aks_node_count" {
  description = "Initial number of nodes in AKS cluster"
  type        = number
  default     = 2
}

variable "aks_min_nodes" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 2
}

variable "aks_max_nodes" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 5
}

variable "aks_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
  # Options:
  # Standard_B2s - $30/month (dev)
  # Standard_D2s_v3 - $70/month (prod)
  # Standard_D4s_v3 - $140/month (high perf)
}

# ================================================================
# PostgreSQL Variables
# ================================================================

variable "postgres_admin_username" {
  description = "PostgreSQL administrator username"
  type        = string
  default     = "pgadmin"
}

variable "postgres_admin_password" {
  description = "PostgreSQL administrator password"
  type        = string
  sensitive   = true
  default     = "YourStrongPassword123!"
  # CHANGE THIS IN PRODUCTION!
}

# ================================================================
# Cosmos DB Variables
# ================================================================

variable "cosmos_enable_free_tier" {
  description = "Enable Cosmos DB free tier (first 400 RU/s free)"
  type        = bool
  default     = true
}

# ================================================================
# Synapse Analytics Variables
# ================================================================

variable "synapse_admin_username" {
  description = "Synapse SQL administrator username"
  type        = string
  default     = "sqladmin"
}

variable "synapse_admin_password" {
  description = "Synapse SQL administrator password"
  type        = string
  sensitive   = true
  default     = "YourStrongPassword123!"
  # CHANGE THIS IN PRODUCTION!
}

variable "aad_admin_login" {
  description = "Azure AD admin login for Synapse"
  type        = string
  default     = "your-email@example.com"
  # CHANGE THIS TO YOUR EMAIL!
}

variable "aad_admin_object_id" {
  description = "Azure AD admin object ID"
  type        = string
  default     = "your-aad-object-id"
  # Get from: az ad signed-in-user show --query id -o tsv
}

variable "aad_admin_tenant_id" {
  description = "Azure AD tenant ID"
  type        = string
  default     = "your-tenant-id"
  # Get from: az account show --query tenantId -o tsv
}

# ================================================================
# Power BI Embedded Variables
# ================================================================

variable "powerbi_sku" {
  description = "Power BI Embedded SKU"
  type        = string
  default     = "A1"
  # A1: $730/month
  # A2: $1,460/month
  # A3: $2,920/month
  # A4: $5,840/month
}

variable "powerbi_admin_email" {
  description = "Power BI administrator email"
  type        = string
  default     = "your-email@example.com"
  # CHANGE THIS TO YOUR EMAIL!
}

# ================================================================
# Azure Functions Variables
# ================================================================

variable "sendgrid_api_key" {
  description = "SendGrid API key for email notifications"
  type        = string
  sensitive   = true
  default     = "your-sendgrid-api-key"
  # Get from: https://app.sendgrid.com/settings/api_keys
}

variable "from_email" {
  description = "From email address for notifications"
  type        = string
  default     = "noreply@example.com"
}

# ================================================================
# Optional Features
# ================================================================

variable "enable_redis" {
  description = "Enable Redis cache"
  type        = bool
  default     = false
  # Set to true to enable Redis caching ($15/month)
}
