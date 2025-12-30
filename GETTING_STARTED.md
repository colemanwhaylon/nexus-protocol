# Nexus Protocol - Getting Started Guide

This guide will help you set up and run the Nexus Protocol platform.

## Prerequisites

### Required Software

| Software | Version | Purpose |
|----------|---------|---------|
| [Foundry](https://getfoundry.sh/) | Latest | Smart contract development |
| [Go](https://golang.org/dl/) | 1.21+ | Backend API server |
| [Docker](https://docker.com/) | Latest | Containerized deployment |
| [Git](https://git-scm.com/) | Latest | Version control |

### Optional Software

| Software | Version | Purpose |
|----------|---------|---------|
| [Python](https://python.org/) | 3.11+ | Scripts and tooling |
| [Node.js](https://nodejs.org/) | 20+ | Frontend (if needed) |
| [Terraform](https://terraform.io/) | 1.5+ | Cloud infrastructure |
| [kubectl](https://kubernetes.io/) | Latest | Kubernetes deployment |

## Quick Start (5 minutes)

### Option 1: Smart Contracts Only

```bash
# 1. Clone the repository
git clone https://github.com/colemanwhaylon/nexus-protocol.git
cd nexus-protocol

# 2. Navigate to contracts directory
cd contracts

# 3. Install dependencies
forge install

# 4. Build all contracts
forge build

# 5. Run all tests (685 tests)
forge test

# 6. Start local blockchain
anvil

# 7. (In new terminal) Deploy contracts locally
forge script script/Counter.s.sol --broadcast --rpc-url http://localhost:8545
```

### Option 2: Full Stack with Docker (Recommended)

```bash
# 1. Clone the repository
git clone https://github.com/colemanwhaylon/nexus-protocol.git
cd nexus-protocol

# 2. Start everything with Docker Compose
cd infrastructure/docker
docker-compose up -d

# This starts:
# - API Server (port 8080)
# - PostgreSQL (port 5432)
# - Redis (port 6379)
# - Prometheus (port 9090)
# - Grafana (port 3000)
```

### Option 3: Development Mode (Backend + Contracts)

```bash
# Terminal 1: Start local blockchain
cd nexus-protocol/contracts
anvil

# Terminal 2: Deploy contracts
cd nexus-protocol/contracts
forge script script/Counter.s.sol --broadcast --rpc-url http://localhost:8545

# Terminal 3: Start API server
cd nexus-protocol/backend
go mod download
go run cmd/server/main.go
```

## Detailed Setup

### 1. Install Foundry

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash

# Reload shell
source ~/.bashrc  # or ~/.zshrc

# Install forge, cast, anvil
foundryup

# Verify installation
forge --version
```

### 2. Install Go

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install golang-go

# macOS
brew install go

# Verify installation
go version
```

### 3. Clone and Setup

```bash
# Clone repository
git clone https://github.com/colemanwhaylon/nexus-protocol.git
cd nexus-protocol

# Install contract dependencies
cd contracts
forge install

# Install Go dependencies
cd ../backend
go mod download
```

## Running the Smart Contracts

### Compile Contracts

```bash
cd contracts

# Build all contracts
forge build

# Build with sizes (useful for gas optimization)
forge build --sizes
```

### Run Tests

```bash
# Run all 685 tests
forge test

# Run with verbose output
forge test -vvv

# Run specific test file
forge test --match-path test/unit/NexusToken.t.sol

# Run fuzz tests (47 tests)
forge test --match-path "test/fuzz/*"

# Run invariant tests (10 tests)
forge test --match-path "test/invariant/*"

# Generate gas report
forge test --gas-report

# Generate coverage report
forge coverage --report summary
```

### Deploy Contracts

```bash
# Start local Anvil node
anvil

# Deploy to local (in new terminal)
forge script script/Counter.s.sol --broadcast --rpc-url http://localhost:8545

# Deploy to Sepolia testnet
forge script script/Counter.s.sol --broadcast --rpc-url $SEPOLIA_RPC_URL --verify

# Deploy upgradeable contracts
forge script script/DeployUpgradeable.s.sol --broadcast --rpc-url http://localhost:8545
```

## Running the Backend

### Development Mode

```bash
cd backend

# Download dependencies
go mod download

# Run the server
go run cmd/server/main.go

# The API will be available at http://localhost:8080
```

### With Environment Variables

```bash
# Create .env file
cat > .env << 'EOF'
DATABASE_URL=sqlite://./nexus.db
CACHE_DRIVER=memory
API_PORT=8080
LOG_LEVEL=debug
EOF

# Run with environment
source .env && go run cmd/server/main.go
```

## Running with Docker

### Development Profile

```bash
cd infrastructure/docker

# Start development stack (SQLite + go-cache)
docker-compose --profile dev up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Production Profile

```bash
cd infrastructure/docker

# Start production stack (PostgreSQL + Redis)
docker-compose --profile production up -d

# Services:
# - nexus-api: http://localhost:8080
# - postgres: localhost:5432
# - redis: localhost:6379
# - prometheus: http://localhost:9090
# - grafana: http://localhost:3000
```

### Build Docker Image

```bash
cd infrastructure/docker

# Build the image
docker build -t nexus-api:latest .

# Run standalone
docker run -p 8080:8080 nexus-api:latest
```

## Running with Kubernetes

### Prerequisites

- kubectl configured
- Kubernetes cluster (local: minikube, kind, or Docker Desktop)

### Deploy

```bash
cd infrastructure/kubernetes

# Create namespace and resources
kubectl apply -k .

# Or apply individually:
kubectl apply -f namespace.yaml
kubectl apply -f configmap.yaml
kubectl apply -f secrets.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# Check status
kubectl get pods -n nexus-protocol
kubectl get services -n nexus-protocol

# View logs
kubectl logs -f deployment/nexus-api -n nexus-protocol
```

## Running Security Tools

### Slither (Static Analysis)

```bash
# Install Slither
pip3 install slither-analyzer

# Run analysis
cd contracts
slither . --config-file ../security/slither/slither.config.json

# Or use the provided script
cd security/slither
./run-slither.sh
```

### Echidna (Fuzzing)

```bash
# Install Echidna (Docker recommended)
docker pull trailofbits/eth-security-toolbox

# Run Echidna tests
cd contracts
echidna . --contract NexusTokenEchidna --config echidna/echidna.yaml
```

## Terraform Cloud Deployment

### AWS

```bash
cd infrastructure/terraform/aws

# Initialize
terraform init

# Plan (development)
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars

# Outputs
terraform output
```

### Azure

```bash
cd infrastructure/terraform/azure

# Login to Azure
az login

# Initialize
terraform init

# Plan
terraform plan -var-file=environments/dev.tfvars

# Apply
terraform apply -var-file=environments/dev.tfvars
```

## Project Statistics

| Component | Count |
|-----------|-------|
| Smart Contracts | 19 (14 core + 3 UUPS + 4 examples) |
| Tests | 685 (611 unit + 47 fuzz + 10 invariant + 17 upgradeable) |
| Backend Handlers | 6 (token, staking, governance, nft, kyc, health) |
| K8s Configs | 13 files |
| Terraform Modules | AWS + Azure |

## Common Issues

### Foundry Not Found

```bash
# Reinstall Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup
source ~/.bashrc
```

### Go Module Issues

```bash
cd backend
go clean -modcache
go mod download
```

### Docker Build Fails

```bash
# Clear Docker cache
docker system prune -a
docker-compose build --no-cache
```

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process
kill -9 <PID>
```

## Next Steps

1. **Explore Contracts**: Read through `contracts/src/` to understand the architecture
2. **Run Tests**: Use `forge test -vvv` to see detailed test execution
3. **Deploy Locally**: Use Anvil and deployment scripts
4. **API Integration**: Start the backend and test endpoints
5. **Security Analysis**: Run Slither and Echidna on contracts

## Support

- **Documentation**: See `/documentation/` for detailed docs
- **Issues**: Report at https://github.com/colemanwhaylon/nexus-protocol/issues
- **Session Log**: See `SESSION_RESUME.md` for development history
