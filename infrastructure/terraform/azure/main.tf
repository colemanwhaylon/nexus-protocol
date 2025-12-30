# Nexus Protocol - Azure Infrastructure
# Terraform configuration for deploying Nexus Protocol to Azure

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.45"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }

  backend "azurerm" {
    resource_group_name  = "nexus-terraform-state"
    storage_account_name = "nexusterraformstate"
    container_name       = "tfstate"
    key                  = "azure/terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = var.environment != "production"
      recover_soft_deleted_key_vaults = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = var.environment == "production"
    }
  }
}

# Data sources
data "azurerm_client_config" "current" {}

data "azuread_client_config" "current" {}

# Local values
locals {
  cluster_name = "nexus-${var.environment}"
  common_tags = {
    Project     = "nexus-protocol"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Resource Group
resource "azurerm_resource_group" "nexus" {
  name     = "${local.cluster_name}-rg"
  location = var.azure_region

  tags = local.common_tags
}

# Virtual Network
resource "azurerm_virtual_network" "nexus" {
  name                = "${local.cluster_name}-vnet"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  address_space       = [var.vnet_cidr]

  tags = local.common_tags
}

# Subnets
resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.nexus.name
  virtual_network_name = azurerm_virtual_network.nexus.name
  address_prefixes     = [var.aks_subnet_cidr]

  service_endpoints = ["Microsoft.Sql", "Microsoft.Storage", "Microsoft.KeyVault"]
}

resource "azurerm_subnet" "postgres" {
  name                 = "postgres-subnet"
  resource_group_name  = azurerm_resource_group.nexus.name
  virtual_network_name = azurerm_virtual_network.nexus.name
  address_prefixes     = [var.postgres_subnet_cidr]

  delegation {
    name = "postgres-delegation"
    service_delegation {
      name = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }

  service_endpoints = ["Microsoft.Storage"]
}

resource "azurerm_subnet" "redis" {
  name                 = "redis-subnet"
  resource_group_name  = azurerm_resource_group.nexus.name
  virtual_network_name = azurerm_virtual_network.nexus.name
  address_prefixes     = [var.redis_subnet_cidr]
}

# Network Security Groups
resource "azurerm_network_security_group" "aks" {
  name                = "${local.cluster_name}-aks-nsg"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name

  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

# Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "nexus" {
  name                = local.cluster_name
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  dns_prefix          = local.cluster_name
  kubernetes_version  = var.kubernetes_version

  default_node_pool {
    name                = "default"
    node_count          = var.node_count
    vm_size             = var.node_vm_size
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = var.node_min_count
    max_count           = var.node_max_count
    os_disk_size_gb     = 100
    os_disk_type        = "Managed"

    node_labels = {
      role = "general"
    }

    tags = local.common_tags
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    outbound_type     = "loadBalancer"
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  azure_policy_enabled = true

  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.nexus.id
  }

  tags = local.common_tags
}

# Additional Node Pool for Blockchain workloads
resource "azurerm_kubernetes_cluster_node_pool" "blockchain" {
  name                  = "blockchain"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.nexus.id
  vm_size               = "Standard_D4s_v3"
  node_count            = 2
  enable_auto_scaling   = true
  min_count             = 1
  max_count             = 5
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_size_gb       = 200
  os_disk_type          = "Managed"

  node_labels = {
    role = "blockchain"
  }

  node_taints = [
    "blockchain=true:NoSchedule"
  ]

  tags = local.common_tags
}

# Azure Container Registry
resource "azurerm_container_registry" "nexus" {
  name                = "nexus${var.environment}acr"
  resource_group_name = azurerm_resource_group.nexus.name
  location            = azurerm_resource_group.nexus.location
  sku                 = var.environment == "production" ? "Premium" : "Standard"
  admin_enabled       = false

  dynamic "georeplications" {
    for_each = var.environment == "production" ? [var.acr_geo_replication_location] : []
    content {
      location                = georeplications.value
      zone_redundancy_enabled = true
    }
  }

  tags = local.common_tags
}

# AKS ACR Integration
resource "azurerm_role_assignment" "aks_acr" {
  principal_id                     = azurerm_kubernetes_cluster.nexus.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.nexus.id
  skip_service_principal_aad_check = true
}

# PostgreSQL Flexible Server
resource "azurerm_private_dns_zone" "postgres" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.nexus.name

  tags = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  name                  = "postgres-dns-link"
  private_dns_zone_name = azurerm_private_dns_zone.postgres.name
  virtual_network_id    = azurerm_virtual_network.nexus.id
  resource_group_name   = azurerm_resource_group.nexus.name
  registration_enabled  = false

  tags = local.common_tags
}

resource "azurerm_postgresql_flexible_server" "nexus" {
  name                   = "${local.cluster_name}-postgres"
  resource_group_name    = azurerm_resource_group.nexus.name
  location               = azurerm_resource_group.nexus.location
  version                = "15"
  delegated_subnet_id    = azurerm_subnet.postgres.id
  private_dns_zone_id    = azurerm_private_dns_zone.postgres.id
  administrator_login    = "nexus_admin"
  administrator_password = random_password.postgres.result
  zone                   = "1"

  storage_mb = var.postgres_storage_mb
  sku_name   = var.postgres_sku

  backup_retention_days        = var.environment == "production" ? 35 : 7
  geo_redundant_backup_enabled = var.environment == "production"

  high_availability {
    mode                      = var.environment == "production" ? "ZoneRedundant" : "SameZone"
    standby_availability_zone = var.environment == "production" ? "2" : null
  }

  tags = local.common_tags

  depends_on = [azurerm_private_dns_zone_virtual_network_link.postgres]
}

resource "azurerm_postgresql_flexible_server_database" "nexus" {
  name      = "nexus"
  server_id = azurerm_postgresql_flexible_server.nexus.id
  collation = "en_US.utf8"
  charset   = "utf8"
}

resource "random_password" "postgres" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Azure Cache for Redis
resource "azurerm_redis_cache" "nexus" {
  name                = "${local.cluster_name}-redis"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  capacity            = var.redis_capacity
  family              = var.redis_family
  sku_name            = var.redis_sku
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"

  redis_configuration {
    maxmemory_reserved = 50
    maxmemory_delta    = 50
    maxmemory_policy   = "volatile-lru"
  }

  tags = local.common_tags
}

# Private Endpoint for Redis
resource "azurerm_private_endpoint" "redis" {
  name                = "${local.cluster_name}-redis-pe"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  subnet_id           = azurerm_subnet.redis.id

  private_service_connection {
    name                           = "redis-connection"
    private_connection_resource_id = azurerm_redis_cache.nexus.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  tags = local.common_tags
}

# Key Vault
resource "azurerm_key_vault" "nexus" {
  name                        = "${local.cluster_name}-kv"
  location                    = azurerm_resource_group.nexus.location
  resource_group_name         = azurerm_resource_group.nexus.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 90
  purge_protection_enabled    = var.environment == "production"
  sku_name                    = "standard"

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }

  tags = local.common_tags
}

resource "azurerm_key_vault_access_policy" "aks" {
  key_vault_id = azurerm_key_vault.nexus.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_kubernetes_cluster.nexus.key_vault_secrets_provider[0].secret_identity[0].object_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Store PostgreSQL password in Key Vault
resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.nexus.id

  depends_on = [azurerm_key_vault_access_policy.aks]
}

# Storage Account
resource "azurerm_storage_account" "nexus" {
  name                     = "nexus${var.environment}storage"
  resource_group_name      = azurerm_resource_group.nexus.name
  location                 = azurerm_resource_group.nexus.location
  account_tier             = "Standard"
  account_replication_type = var.environment == "production" ? "GRS" : "LRS"

  blob_properties {
    versioning_enabled = true
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
  }

  network_rules {
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
    bypass                     = ["AzureServices"]
  }

  tags = local.common_tags
}

resource "azurerm_storage_container" "artifacts" {
  name                  = "artifacts"
  storage_account_name  = azurerm_storage_account.nexus.name
  container_access_type = "private"
}

# Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "nexus" {
  name                = "${local.cluster_name}-logs"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  sku                 = "PerGB2018"
  retention_in_days   = var.environment == "production" ? 90 : 30

  tags = local.common_tags
}

# Application Insights
resource "azurerm_application_insights" "nexus" {
  name                = "${local.cluster_name}-appinsights"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name
  workspace_id        = azurerm_log_analytics_workspace.nexus.id
  application_type    = "web"

  tags = local.common_tags
}

# Workload Identity for Nexus API
resource "azurerm_user_assigned_identity" "nexus_api" {
  name                = "${local.cluster_name}-api-identity"
  location            = azurerm_resource_group.nexus.location
  resource_group_name = azurerm_resource_group.nexus.name

  tags = local.common_tags
}

resource "azurerm_federated_identity_credential" "nexus_api" {
  name                = "nexus-api-federated"
  resource_group_name = azurerm_resource_group.nexus.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.nexus.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.nexus_api.id
  subject             = "system:serviceaccount:nexus-protocol:nexus-api"
}

# Role assignments for Workload Identity
resource "azurerm_role_assignment" "nexus_api_storage" {
  scope                = azurerm_storage_account.nexus.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.nexus_api.principal_id
}

resource "azurerm_key_vault_access_policy" "nexus_api" {
  key_vault_id = azurerm_key_vault.nexus.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.nexus_api.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}
