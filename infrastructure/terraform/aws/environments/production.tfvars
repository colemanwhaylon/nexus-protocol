# Nexus Protocol - AWS Production Environment

environment = "production"
aws_region  = "us-east-1"

# VPC
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS
kubernetes_version  = "1.28"
node_instance_types = ["m5.large", "m5.xlarge"]
node_min_size       = 3
node_max_size       = 20
node_desired_size   = 5

# RDS
rds_instance_class        = "db.r6g.large"
rds_allocated_storage     = 100
rds_max_allocated_storage = 500

# Redis
redis_node_type = "cache.r6g.large"
