# Nexus Protocol - Azure Terraform Outputs

output "resource_group_name" {
  description = "Resource group name"
  value       = azurerm_resource_group.nexus.name
}

output "resource_group_location" {
  description = "Resource group location"
  value       = azurerm_resource_group.nexus.location
}

output "vnet_id" {
  description = "Virtual Network ID"
  value       = azurerm_virtual_network.nexus.id
}

output "vnet_name" {
  description = "Virtual Network name"
  value       = azurerm_virtual_network.nexus.name
}

output "aks_subnet_id" {
  description = "AKS subnet ID"
  value       = azurerm_subnet.aks.id
}

output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.nexus.name
}

output "aks_cluster_id" {
  description = "AKS cluster ID"
  value       = azurerm_kubernetes_cluster.nexus.id
}

output "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL for workload identity"
  value       = azurerm_kubernetes_cluster.nexus.oidc_issuer_url
}

output "aks_kube_config" {
  description = "AKS kubeconfig"
  value       = azurerm_kubernetes_cluster.nexus.kube_config_raw
  sensitive   = true
}

output "acr_login_server" {
  description = "Container Registry login server"
  value       = azurerm_container_registry.nexus.login_server
}

output "acr_name" {
  description = "Container Registry name"
  value       = azurerm_container_registry.nexus.name
}

output "postgres_fqdn" {
  description = "PostgreSQL Flexible Server FQDN"
  value       = azurerm_postgresql_flexible_server.nexus.fqdn
}

output "postgres_server_name" {
  description = "PostgreSQL server name"
  value       = azurerm_postgresql_flexible_server.nexus.name
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = azurerm_postgresql_flexible_server_database.nexus.name
}

output "postgres_admin_login" {
  description = "PostgreSQL admin login"
  value       = azurerm_postgresql_flexible_server.nexus.administrator_login
}

output "redis_hostname" {
  description = "Redis Cache hostname"
  value       = azurerm_redis_cache.nexus.hostname
}

output "redis_port" {
  description = "Redis Cache SSL port"
  value       = azurerm_redis_cache.nexus.ssl_port
}

output "redis_primary_access_key" {
  description = "Redis Cache primary access key"
  value       = azurerm_redis_cache.nexus.primary_access_key
  sensitive   = true
}

output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.nexus.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.nexus.vault_uri
}

output "storage_account_name" {
  description = "Storage Account name"
  value       = azurerm_storage_account.nexus.name
}

output "storage_account_primary_blob_endpoint" {
  description = "Storage Account primary blob endpoint"
  value       = azurerm_storage_account.nexus.primary_blob_endpoint
}

output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = azurerm_log_analytics_workspace.nexus.id
}

output "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key"
  value       = azurerm_application_insights.nexus.instrumentation_key
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Application Insights connection string"
  value       = azurerm_application_insights.nexus.connection_string
  sensitive   = true
}

output "nexus_api_identity_client_id" {
  description = "Nexus API workload identity client ID"
  value       = azurerm_user_assigned_identity.nexus_api.client_id
}

output "nexus_api_identity_principal_id" {
  description = "Nexus API workload identity principal ID"
  value       = azurerm_user_assigned_identity.nexus_api.principal_id
}

# Kubernetes configuration command
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "az aks get-credentials --resource-group ${azurerm_resource_group.nexus.name} --name ${azurerm_kubernetes_cluster.nexus.name}"
}

# Docker login command
output "docker_login" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${azurerm_container_registry.nexus.name}"
}
