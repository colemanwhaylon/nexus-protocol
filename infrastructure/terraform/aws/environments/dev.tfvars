# Nexus Protocol - AWS Development Environment

environment = "dev"
aws_region  = "us-east-1"

# VPC
vpc_cidr        = "10.0.0.0/16"
private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS
kubernetes_version  = "1.28"
node_instance_types = ["t3.medium", "t3.large"]
node_min_size       = 1
node_max_size       = 5
node_desired_size   = 2

# RDS
rds_instance_class        = "db.t3.micro"
rds_allocated_storage     = 20
rds_max_allocated_storage = 50

# Redis
redis_node_type = "cache.t3.micro"
