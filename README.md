# Nexus Protocol

> A comprehensive DeFi + NFT + Enterprise Tokenization platform demonstrating production-grade smart contract security, blockchain infrastructure, and full-stack development.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-blue.svg)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange.svg)](https://getfoundry.sh/)

## Overview

Nexus Protocol is a full-stack blockchain platform featuring:

- **Core Token Contracts**: ERC-20 with snapshots/permit/votes, ERC-721A for gas-efficient NFTs, ERC-1400 security tokens
- **DeFi Mechanics**: Staking with slashing, streaming rewards, vesting schedules, Merkle airdrops
- **DAO Governance**: OpenZeppelin Governor, Timelock, MultiSig wallet
- **Enterprise Compliance**: KYC/AML registry, RBAC, emergency controls, custody patterns
- **Security Infrastructure**: Echidna fuzzing, Certora formal verification, custom Slither/Aderyn rules
- **Backend Services**: Go API server, Rust CLI tools, Python analytics scripts
- **Cloud Infrastructure**: Docker, Kubernetes, Terraform (AWS/GCP/Azure)

## Quick Start

### Prerequisites

- [Foundry](https://getfoundry.sh/) (forge, cast, anvil)
- [Go 1.21+](https://golang.org/dl/)
- [Rust](https://rustup.rs/)
- [Python 3.11+](https://python.org/)
- [Node.js 20+](https://nodejs.org/)
- [Docker](https://docker.com/)

### Installation

```bash
# Clone the repository
git clone https://github.com/colemanwhaylon/nexus-protocol.git
cd nexus-protocol

# Install contract dependencies
cd contracts
forge install

# Build contracts
forge build

# Run tests
forge test
```

### Running the Development Environment

```bash
# Start local Anvil node
anvil

# In another terminal, deploy contracts
forge script script/Deploy.s.sol --broadcast --rpc-url http://localhost:8545

# Start the API server
cd ../backend
go run cmd/server/main.go

# Or use Docker Compose
docker-compose --profile dev up
```

## Project Structure

```
nexus-protocol/
├── contracts/                 # Solidity smart contracts
│   ├── src/
│   │   ├── core/             # NexusToken, NexusNFT, NexusSecurityToken
│   │   ├── defi/             # Staking, Rewards, Vesting, Airdrop, Oracle
│   │   ├── governance/       # Governor, Timelock, MultiSig
│   │   ├── security/         # AccessControl, KYC, Emergency, Custody
│   │   ├── upgradeable/      # UUPS proxy implementations
│   │   ├── bridge/           # Cross-chain contracts
│   │   ├── examples/         # Vulnerable/Secure contract pairs
│   │   ├── interfaces/       # Contract interfaces
│   │   └── libraries/        # Shared libraries
│   ├── test/
│   │   ├── unit/             # Unit tests
│   │   ├── integration/      # Integration tests
│   │   ├── fuzz/             # Fuzz tests
│   │   ├── invariant/        # Invariant tests
│   │   ├── fork/             # Mainnet fork tests
│   │   └── gas/              # Gas benchmarks
│   ├── script/               # Deployment scripts
│   ├── echidna/              # Echidna fuzzing configs
│   └── certora/              # Certora formal verification specs
├── backend/                   # Go API server
│   ├── cmd/server/
│   ├── internal/
│   │   ├── api/              # HTTP handlers, middleware, routes
│   │   ├── blockchain/       # Ethereum client, contract bindings
│   │   ├── storage/          # Database (SQLite/PostgreSQL)
│   │   └── cache/            # Cache (go-cache/Redis)
│   └── pkg/models/
├── scripts/                   # Python tooling
│   ├── merkle/               # Merkle tree generation
│   ├── analytics/            # Gas reports, compliance exports
│   └── deployment/           # Deployment verification
├── tools/                     # Rust tooling
│   ├── nexus-cli/            # CLI tool
│   └── aderyn-rules/         # Custom Aderyn rules
├── infrastructure/            # DevOps
│   ├── docker/               # Dockerfiles
│   ├── kubernetes/           # K8s manifests
│   ├── terraform/            # Cloud infrastructure
│   └── monitoring/           # Grafana, Tenderly configs
├── security/                  # Security tooling
│   ├── slither/              # Custom Slither detectors
│   └── threat-models/        # STRIDE analysis
└── documentation/             # Project documentation
```

## Core Contracts

### NexusToken (ERC-20)
Full-featured ERC-20 with:
- ERC20Snapshot for governance snapshots
- ERC20Permit (EIP-2612) for gasless approvals
- ERC20Votes for delegation
- Blocklist functionality
- Flash minting capability

### NexusNFT (ERC-721A)
Gas-efficient NFT with:
- Batch minting via ERC-721A
- EIP-2981 royalty support
- Reveal mechanism
- Soulbound option
- IPFS metadata integration

### NexusSecurityToken (ERC-1400)
Enterprise security token with:
- Partition-based holdings
- Transfer restrictions with whitelist
- Document management (legal docs hash)
- Forced transfers for compliance
- Controller operations

## DeFi Features

### Staking
- Flexible stake/unstake with configurable lock periods
- Slashing conditions for protocol violations
- Delegation support for liquid staking
- Checkpoint-based accounting
- Emergency withdrawal with penalty

### Rewards Distribution
- Streaming rewards (per-second accrual)
- Merkle-based claim distribution
- Multi-token reward support
- Epoch-based distribution cycles
- Auto-compounding options

### Vesting
- Linear vesting schedules
- Cliff + vesting combinations
- Revocable grants for employees
- Beneficiary transfer capability

### Airdrops
- Merkle tree verification
- Configurable claim windows
- Vested claim options
- NFT airdrop support
- Anti-sybil mechanisms

## Governance

### Governor
- OpenZeppelin Governor pattern
- Proposal creation and voting
- Vote delegation
- Configurable quorum requirements
- Timelock integration

### Timelock
- 48-hour default delay
- Execute/Cancel queue
- Emergency bypass mechanism
- Role-based management

### MultiSig
- N-of-M signature requirement
- Daily spending limits
- Transaction queue management
- Owner rotation

## Security Features

### Access Control
- Hierarchical RBAC (ADMIN, OPERATOR, COMPLIANCE, PAUSER, UPGRADER)
- Granular permissions per function
- Role expiration support

### KYC/AML Registry
- Whitelist/Blacklist management
- Jurisdiction tracking
- Attestation system
- Expiration timestamps

### Emergency Controls
- Global protocol pause
- Per-contract pause capability
- Rate limiting
- Drain protection
- Recovery procedures

## Testing

```bash
# Run all tests
forge test

# Run with verbosity
forge test -vvv

# Run specific test file
forge test --match-path test/unit/NexusToken.t.sol

# Run fuzz tests
forge test --match-contract Fuzz

# Run invariant tests
forge test --match-contract Invariant

# Run fork tests
forge test --fork-url $ETH_RPC_URL --match-contract Fork

# Gas report
forge test --gas-report

# Coverage
forge coverage
```

### Security Testing

```bash
# Slither static analysis
slither contracts/src/

# Echidna fuzzing
echidna contracts/src/core/NexusToken.sol --config echidna/config.yaml

# Certora formal verification
certoraRun certora/conf/NexusToken.conf

# Aderyn analysis
aderyn contracts/src/
```

## Deployment

### Local (Anvil)
```bash
forge script script/Deploy.s.sol --broadcast --rpc-url http://localhost:8545
```

### Testnet (Sepolia)
```bash
forge script script/Deploy.s.sol --broadcast --rpc-url $SEPOLIA_RPC_URL --verify
```

### Multi-chain
```bash
# Arbitrum Sepolia
forge script script/Deploy.s.sol --broadcast --rpc-url $ARB_SEPOLIA_RPC_URL

# Polygon Amoy
forge script script/Deploy.s.sol --broadcast --rpc-url $POLYGON_AMOY_RPC_URL

# Base Sepolia
forge script script/Deploy.s.sol --broadcast --rpc-url $BASE_SEPOLIA_RPC_URL
```

## API Server

The Go API server provides:
- JWT authentication
- Airdrop management endpoints
- Staking operations
- Governance proposal management
- KYC/AML compliance (RBAC protected)
- Analytics and metrics

See [API Documentation](documentation/API.md) for full endpoint reference.

## Configuration

### Database
The backend supports switchable database backends:
- **SQLite** (embedded) - For development and demos
- **PostgreSQL** - For production

```yaml
database:
  driver: sqlite  # or "postgres"
  sqlite:
    path: ./data/nexus.db
  postgres:
    host: localhost
    port: 5432
    database: nexus
```

### Cache
The backend supports switchable cache backends:
- **go-cache** (in-memory) - For development and demos
- **Redis** - For production

```yaml
cache:
  driver: memory  # or "redis"
  memory:
    default_ttl: 5m
  redis:
    host: localhost
    port: 6379
```

## Docker Deployment

```bash
# Development (single container)
docker-compose --profile dev up

# Demo (single container, SQLite + go-cache)
docker-compose --profile demo up

# Production (full stack)
docker-compose --profile production up
```

## Documentation

- [Architecture](documentation/ARCHITECTURE.md) - System design and components
- [Security Audit](documentation/SECURITY_AUDIT.md) - Self-audit report
- [Tokenomics](documentation/TOKENOMICS.md) - Token economics design
- [Key Management](documentation/KEY_MANAGEMENT.md) - HSM/MPC patterns
- [Incident Response](documentation/INCIDENT_RESPONSE.md) - Emergency runbook
- [Gas Optimization](documentation/GAS_OPTIMIZATION.md) - Optimization techniques
- [Compliance](documentation/COMPLIANCE.md) - Regulatory considerations
- [API Reference](documentation/API.md) - Backend API documentation
- [Threat Model](documentation/THREAT_MODEL.md) - STRIDE analysis

## Skills Demonstrated

This project demonstrates expertise in:

| Category | Skills |
|----------|--------|
| Smart Contract Security | Foundry, Echidna, Certora, Slither, Custom detectors |
| Blockchain Infrastructure | EVM, ERC-20/721/1400, MultiSig, Governance, Upgradeable, Oracle, L2 |
| Wallet & Key Management | Custodial patterns, HSM integration, WalletConnect |
| Enterprise/Compliance | RBAC, KYC/AML, Audit trail, DvP settlement, Circuit breakers |
| Backend/Infrastructure | Go, Python, Rust, Cloud, Docker/K8s, CI/CD, Monitoring |
| Security Process | Threat modeling, Self-audit, Incident response |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
- [Foundry](https://github.com/foundry-rs/foundry)
- [ERC-721A](https://github.com/chiru-labs/ERC721A)
- [Chainlink](https://chain.link/)
