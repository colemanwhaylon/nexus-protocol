# Nexus Protocol - Azure Development Environment

environment  = "dev"
azure_region = "eastus"

# VNet
vnet_cidr            = "10.0.0.0/16"
aks_subnet_cidr      = "10.0.0.0/20"
postgres_subnet_cidr = "10.0.16.0/24"
redis_subnet_cidr    = "10.0.17.0/24"

# AKS
kubernetes_version = "1.28"
node_count         = 2
node_vm_size       = "Standard_B2s"
node_min_count     = 1
node_max_count     = 5

# PostgreSQL
postgres_sku        = "B_Standard_B1ms"
postgres_storage_mb = 32768

# Redis
redis_sku      = "Basic"
redis_family   = "C"
redis_capacity = 0
