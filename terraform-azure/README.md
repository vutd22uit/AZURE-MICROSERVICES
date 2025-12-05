# 🏗️ Terraform Azure Infrastructure

This directory contains Terraform configuration for deploying all Azure resources needed for the E-Commerce Cloud-Native system.

## 📦 Resources Created

### Compute
- ✅ **Azure Kubernetes Service (AKS)** - Container orchestration (2-5 nodes, auto-scaling)
- ✅ **Azure Functions** - Serverless compute (Payment + Email)

### Storage & Databases
- ✅ **Azure Database for PostgreSQL** - Relational database for Auth Service
- ✅ **Azure Cosmos DB** - NoSQL database for Orders Service (Serverless)
- ✅ **Storage Accounts** - Blob storage for Functions and Synapse

### Analytics & BI
- ✅ **Azure Synapse Analytics** - Data warehouse (DW100c)
- ✅ **Azure Data Factory** - ETL orchestration
- ✅ **Power BI Embedded** - Business intelligence (A1 capacity)

### Networking & Security
- ✅ **Azure Container Registry (ACR)** - Docker image registry
- ✅ **Application Insights** - Monitoring & logging
- ✅ **Log Analytics Workspace** - Centralized logging

### Optional
- ⚪ **Azure Redis Cache** - Distributed caching (disabled by default)

## 🚀 Quick Start

### Prerequisites

```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Install Terraform
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify installations
az --version
terraform --version
```

### Azure Login

```bash
# Login to Azure
az login

# List subscriptions
az account list --output table

# Set subscription (if multiple)
az account set --subscription "YOUR_SUBSCRIPTION_ID"

# Verify current subscription
az account show
```

### Configure Variables

Before deploying, update `variables.tf` or create `terraform.tfvars`:

```bash
# Get your Azure AD information
az ad signed-in-user show --query "{email:mail, objectId:id}" -o table

# Get tenant ID
az account show --query tenantId -o tsv
```

**Create `terraform.tfvars`:**

```hcl
# General
project_name        = "ecommerce-cloud"
resource_group_name = "ecommerce-cloud-rg"
location            = "Southeast Asia"

# AKS
aks_node_count = 2
aks_min_nodes  = 2
aks_max_nodes  = 5
aks_vm_size    = "Standard_D2s_v3"

# PostgreSQL
postgres_admin_username = "pgadmin"
postgres_admin_password = "YourStrongPassword123!"  # CHANGE THIS!

# Synapse
synapse_admin_username = "sqladmin"
synapse_admin_password = "YourStrongPassword123!"  # CHANGE THIS!
aad_admin_login        = "your-email@example.com"  # YOUR EMAIL
aad_admin_object_id    = "your-aad-object-id"      # FROM ABOVE
aad_admin_tenant_id    = "your-tenant-id"          # FROM ABOVE

# Power BI
powerbi_sku         = "A1"
powerbi_admin_email = "your-email@example.com"  # YOUR EMAIL

# Functions
sendgrid_api_key = "your-sendgrid-api-key"  # Optional
from_email       = "noreply@example.com"

# Optional Features
enable_redis = false  # Set to true to enable Redis ($15/month)
```

### Deploy Infrastructure

```bash
cd terraform-azure

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review execution plan
terraform plan -out=tfplan

# Apply configuration (create resources)
terraform apply tfplan
# Deployment time: 15-20 minutes

# Save outputs to file
terraform output > ../infrastructure-outputs.txt
terraform output -json > ../infrastructure-outputs.json
```

### Verify Deployment

```bash
# View summary
terraform output summary

# Get quick start commands
terraform output quick_start_commands

# Check specific outputs
terraform output aks_cluster_name
terraform output acr_login_server
terraform output postgres_server_fqdn
terraform output cosmos_db_endpoint
```

## 📋 Post-Deployment Steps

### 1. Configure kubectl for AKS

```bash
# Get AKS credentials
az aks get-credentials \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name)

# Verify connection
kubectl get nodes
```

### 2. Login to Azure Container Registry

```bash
# Login to ACR
az acr login --name $(terraform output -raw acr_login_server | cut -d'.' -f1)

# Verify login
az acr repository list --name $(terraform output -raw acr_login_server | cut -d'.' -f1)
```

### 3. Initialize Databases

**PostgreSQL:**
```bash
# Get connection string
POSTGRES_HOST=$(terraform output -raw postgres_server_fqdn)
POSTGRES_USER="pgadmin"
POSTGRES_PASSWORD="YourStrongPassword123!"  # FROM tfvars
POSTGRES_DB="authdb"

# Connect using psql
psql "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:5432/${POSTGRES_DB}?sslmode=require"

# Or connect from Azure Cloud Shell
az postgres flexible-server connect \
  --name $(terraform output -raw postgres_server_name) \
  --admin-user pgadmin \
  --database authdb
```

**Cosmos DB:**
```bash
# Cosmos DB is ready to use
# Containers are already created: products, orders, cart
# Use the endpoint and key from outputs
```

### 4. Setup Synapse Analytics

```bash
# Get Synapse connection info
SYNAPSE_WORKSPACE=$(terraform output -raw synapse_workspace_name)
SYNAPSE_SQL_ENDPOINT=$(terraform output -raw synapse_sql_endpoint)

# Connect to Synapse (use Azure Data Studio or Azure Portal)
# Server: <synapse-workspace>.sql.azuresynapse.net
# Database: ecommercedw
# Authentication: SQL Authentication
# User: sqladmin
# Password: (from tfvars)

# Or use Azure CLI
az synapse sql pool show \
  --name ecommercedw \
  --workspace-name $SYNAPSE_WORKSPACE \
  --resource-group $(terraform output -raw resource_group_name)

# IMPORTANT: Pause SQL pool when not in use to save costs
az synapse sql pool pause \
  --name ecommercedw \
  --workspace-name $SYNAPSE_WORKSPACE \
  --resource-group $(terraform output -raw resource_group_name)
```

### 5. Configure Data Factory

```bash
# Data Factory is created with linked services
# Pipeline definition will be added later

# View Data Factory
az datafactory show \
  --name $(terraform output -raw data_factory_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### 6. Deploy Azure Functions

```bash
# Functions are created but need code deployment
# See /azure-functions directory for function code

cd ../azure-functions

# Deploy Payment Function
cd payment-processor
func azure functionapp publish $(terraform output -raw payment_function_url | cut -d'/' -f3 | cut -d'.' -f1)

# Deploy Email Function
cd ../email-notification
func azure functionapp publish $(terraform output -raw email_function_url | cut -d'/' -f3 | cut -d'.' -f1)
```

## 💰 Cost Estimation

### Monthly Costs (Production)

| Service | SKU | Monthly Cost (USD) |
|---------|-----|-------------------|
| AKS | 2 x Standard_D2s_v3 | $140 |
| PostgreSQL | GP_Standard_D2s_v3 | $30 |
| Cosmos DB | Serverless (free tier) | $0-50 |
| Synapse SQL Pool | DW100c (paused 20h/day) | $120 |
| Data Factory | 720 runs/month | $10 |
| Power BI Embedded | A1 | $730 |
| Functions | Consumption | $5 |
| Storage | Standard LRS | $5 |
| ACR | Standard | $5 |
| Application Insights | 5GB/month | $10 |
| **TOTAL** | | **~$1,055/month** |

### Cost Optimization Tips

#### 1. Pause Synapse when not in use
```bash
# Pause after demo/working hours
az synapse sql pool pause \
  --name ecommercedw \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name)

# Savings: ~$600/month if paused 20h/day
```

#### 2. Use smaller AKS nodes for development
```hcl
# In terraform.tfvars
aks_vm_size = "Standard_B2s"  # $30/month vs $70/month

# Savings: ~$80/month for development
```

#### 3. Enable Cosmos DB Free Tier
```hcl
# In terraform.tfvars
cosmos_enable_free_tier = true  # First 400 RU/s free

# Savings: ~$50/month
```

#### 4. Use Power BI Development Mode
```hcl
# For development only
powerbi_sku = "A1"  # $730/month

# For production
powerbi_sku = "A3"  # $2,920/month but better performance
```

#### 5. Delete resources when not in use
```bash
# Destroy all resources
terraform destroy

# Re-create when needed
terraform apply
```

### Development Environment Cost

For development, use these settings in `terraform.tfvars`:

```hcl
aks_vm_size             = "Standard_B2s"
cosmos_enable_free_tier = true
powerbi_sku             = "A1"
enable_redis            = false
```

**Development monthly cost: ~$320/month**

## 🔧 Management Commands

### View Resources

```bash
# List all resources in resource group
az resource list \
  --resource-group $(terraform output -raw resource_group_name) \
  --output table

# Show resource group
az group show \
  --name $(terraform output -raw resource_group_name)
```

### Pause/Resume Synapse

```bash
# Pause SQL Pool
az synapse sql pool pause \
  --name ecommercedw \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name)

# Resume SQL Pool
az synapse sql pool resume \
  --name ecommercedw \
  --workspace-name $(terraform output -raw synapse_workspace_name) \
  --resource-group $(terraform output -raw resource_group_name)
```

### Scale AKS

```bash
# Scale node count
az aks scale \
  --resource-group $(terraform output -raw resource_group_name) \
  --name $(terraform output -raw aks_cluster_name) \
  --node-count 3
```

### View Logs

```bash
# Application Insights logs
az monitor app-insights query \
  --app $(terraform output -raw appinsights_instrumentation_key) \
  --analytics-query "requests | take 10"

# Function logs
az functionapp log tail \
  --name <function-app-name> \
  --resource-group $(terraform output -raw resource_group_name)
```

## 🗑️ Cleanup

### Destroy All Resources

```bash
# CAUTION: This will delete everything!
terraform destroy

# Or delete resource group directly
az group delete \
  --name $(terraform output -raw resource_group_name) \
  --yes \
  --no-wait
```

### Selective Cleanup

```bash
# Remove specific resource
terraform destroy -target=azurerm_powerbi_embedded.powerbi

# Re-plan after removal
terraform plan
```

## 🐛 Troubleshooting

### Issue: Terraform state is locked

```bash
# Force unlock
terraform force-unlock <lock-id>
```

### Issue: Insufficient quota

```bash
# Check quota
az vm list-usage --location "Southeast Asia" --output table

# Request quota increase
# Go to Azure Portal → Subscriptions → Usage + quotas
```

### Issue: Resource already exists

```bash
# Import existing resource
terraform import azurerm_resource_group.main /subscriptions/<sub-id>/resourceGroups/ecommerce-cloud-rg

# Or destroy and recreate
terraform destroy -target=<resource>
terraform apply
```

### Issue: Authentication errors

```bash
# Re-login to Azure
az logout
az login

# Clear Terraform cache
rm -rf .terraform
terraform init
```

## 📚 Additional Resources

- [Azure CLI Documentation](https://docs.microsoft.com/cli/azure/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
- [Azure Architecture Center](https://docs.microsoft.com/azure/architecture/)

## 🔐 Security Notes

1. **Never commit `terraform.tfvars`** - It contains sensitive passwords
2. **Use Azure Key Vault** for production secrets
3. **Enable Azure Security Center** for security recommendations
4. **Configure firewall rules** to restrict access
5. **Rotate passwords regularly**
6. **Use Managed Identities** where possible

---

**Next Steps:**
1. ✅ Deploy infrastructure with Terraform
2. 🔄 Configure Kubernetes secrets
3. 🔄 Deploy microservices to AKS
4. 🔄 Setup data pipeline
5. 🔄 Configure Power BI

See main [README.md](../README.md) for complete project documentation.
