# Nexus Protocol - Terraform Infrastructure

This directory contains Terraform configurations for deploying Nexus Protocol to cloud providers.

## Supported Cloud Providers

- **AWS**: EKS, RDS PostgreSQL, ElastiCache Redis, S3, KMS
- **Azure**: AKS, PostgreSQL Flexible Server, Redis Cache, Key Vault, Storage

## Prerequisites

### AWS
```bash
# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Configure credentials
aws configure

# Install Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

### Azure
```bash
# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Login
az login

# Set subscription
az account set --subscription <subscription-id>
```

## Directory Structure

```
terraform/
├── aws/
│   ├── main.tf              # Main AWS configuration
│   ├── variables.tf         # Variable definitions
│   ├── outputs.tf           # Output definitions
│   └── environments/
│       ├── dev.tfvars       # Development values
│       └── production.tfvars # Production values
├── azure/
│   ├── main.tf              # Main Azure configuration
│   ├── variables.tf         # Variable definitions
│   ├── outputs.tf           # Output definitions
│   └── environments/
│       ├── dev.tfvars       # Development values
│       └── production.tfvars # Production values
└── README.md
```

## Usage

### Initialize Terraform

**AWS:**
```bash
cd aws
terraform init
```

**Azure:**
```bash
cd azure
terraform init
```

### Plan Changes

**Development:**
```bash
terraform plan -var-file=environments/dev.tfvars
```

**Production:**
```bash
terraform plan -var-file=environments/production.tfvars
```

### Apply Changes

**Development:**
```bash
terraform apply -var-file=environments/dev.tfvars
```

**Production:**
```bash
terraform apply -var-file=environments/production.tfvars
```

### Destroy Infrastructure

```bash
terraform destroy -var-file=environments/<env>.tfvars
```

## State Management

### AWS
State is stored in S3 with DynamoDB locking. Create the backend resources first:

```bash
# Create S3 bucket for state
aws s3api create-bucket \
  --bucket nexus-protocol-terraform-state \
  --region us-east-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket nexus-protocol-terraform-state \
  --versioning-configuration Status=Enabled

# Create DynamoDB table for locking
aws dynamodb create-table \
  --table-name nexus-protocol-terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Azure
State is stored in Azure Storage. Create the backend resources first:

```bash
# Create resource group
az group create --name nexus-terraform-state --location eastus

# Create storage account
az storage account create \
  --name nexusterraformstate \
  --resource-group nexus-terraform-state \
  --location eastus \
  --sku Standard_LRS

# Create container
az storage container create \
  --name tfstate \
  --account-name nexusterraformstate
```

## Connecting to Kubernetes

After deployment, configure kubectl:

**AWS:**
```bash
aws eks update-kubeconfig --region us-east-1 --name nexus-<environment>
```

**Azure:**
```bash
az aks get-credentials --resource-group nexus-<environment>-rg --name nexus-<environment>
```

## Resource Summary

### Development Environment
| Resource | AWS | Azure |
|----------|-----|-------|
| Kubernetes | EKS (t3.medium, 1-5 nodes) | AKS (Standard_B2s, 1-5 nodes) |
| Database | RDS PostgreSQL (db.t3.micro) | PostgreSQL Flex (B_Standard_B1ms) |
| Cache | ElastiCache (cache.t3.micro) | Redis Cache (Basic C0) |
| Storage | S3 | Blob Storage |
| Secrets | Secrets Manager + KMS | Key Vault |

### Production Environment
| Resource | AWS | Azure |
|----------|-----|-------|
| Kubernetes | EKS (m5.large, 3-20 nodes) | AKS (Standard_D4s_v3, 3-20 nodes) |
| Database | RDS PostgreSQL (db.r6g.large, Multi-AZ) | PostgreSQL Flex (GP_Standard_D4s_v3, HA) |
| Cache | ElastiCache (cache.r6g.large, 3 nodes) | Redis Cache (Premium P1) |
| Storage | S3 (versioned, encrypted) | Blob Storage (GRS) |
| Secrets | Secrets Manager + KMS | Key Vault (purge protected) |

## Security Features

- All databases are deployed in private subnets
- Encryption at rest and in transit enabled
- Network policies and security groups configured
- Workload Identity / IRSA for pod authentication
- Key management with KMS / Key Vault
- Audit logging enabled

## Cost Estimation

Use `terraform plan` with the Infracost tool:

```bash
# Install Infracost
curl -fsSL https://raw.githubusercontent.com/infracost/infracost/master/scripts/install.sh | sh

# Generate cost estimate
infracost breakdown --path .
```

## Troubleshooting

### Common Issues

1. **State Lock Error**: Delete the lock manually
   ```bash
   # AWS
   aws dynamodb delete-item --table-name nexus-protocol-terraform-locks --key '{"LockID":{"S":"<lock-id>"}}'

   # Azure
   az storage blob lease break --blob-name azure/terraform.tfstate --container-name tfstate --account-name nexusterraformstate
   ```

2. **Permission Denied**: Check IAM/RBAC permissions for the service principal

3. **Resource Limits**: Check quotas in your cloud account
   ```bash
   # AWS
   aws service-quotas list-service-quotas --service-code eks

   # Azure
   az vm list-usage --location eastus --output table
   ```
