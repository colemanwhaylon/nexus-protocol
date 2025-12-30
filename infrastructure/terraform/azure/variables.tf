# Nexus Protocol - Azure Terraform Variables

variable "azure_region" {
  description = "Azure region for deployment"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# VNet Configuration
variable "vnet_cidr" {
  description = "CIDR block for VNet"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "CIDR block for AKS subnet"
  type        = string
  default     = "10.0.0.0/20"
}

variable "postgres_subnet_cidr" {
  description = "CIDR block for PostgreSQL subnet"
  type        = string
  default     = "10.0.16.0/24"
}

variable "redis_subnet_cidr" {
  description = "CIDR block for Redis subnet"
  type        = string
  default     = "10.0.17.0/24"
}

# AKS Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.28"
}

variable "node_count" {
  description = "Initial number of nodes in default node pool"
  type        = number
  default     = 3
}

variable "node_vm_size" {
  description = "VM size for AKS nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "node_min_count" {
  description = "Minimum number of nodes in default node pool"
  type        = number
  default     = 2
}

variable "node_max_count" {
  description = "Maximum number of nodes in default node pool"
  type        = number
  default     = 10
}

# PostgreSQL Configuration
variable "postgres_sku" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "GP_Standard_D2s_v3"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 32768
}

# Redis Configuration
variable "redis_sku" {
  description = "Redis Cache SKU"
  type        = string
  default     = "Standard"
}

variable "redis_family" {
  description = "Redis Cache family"
  type        = string
  default     = "C"
}

variable "redis_capacity" {
  description = "Redis Cache capacity"
  type        = number
  default     = 1
}

# Container Registry
variable "acr_geo_replication_location" {
  description = "ACR geo-replication location for production"
  type        = string
  default     = "westus"
}

# Domain Configuration
variable "domain_name" {
  description = "Custom domain name for the application"
  type        = string
  default     = ""
}
