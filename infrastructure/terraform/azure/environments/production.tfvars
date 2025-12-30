# Nexus Protocol - Azure Production Environment

environment  = "production"
azure_region = "eastus"

# VNet
vnet_cidr            = "10.0.0.0/16"
aks_subnet_cidr      = "10.0.0.0/20"
postgres_subnet_cidr = "10.0.16.0/24"
redis_subnet_cidr    = "10.0.17.0/24"

# AKS
kubernetes_version = "1.28"
node_count         = 5
node_vm_size       = "Standard_D4s_v3"
node_min_count     = 3
node_max_count     = 20

# PostgreSQL
postgres_sku        = "GP_Standard_D4s_v3"
postgres_storage_mb = 131072

# Redis
redis_sku      = "Premium"
redis_family   = "P"
redis_capacity = 1

# ACR Geo-replication
acr_geo_replication_location = "westus"
