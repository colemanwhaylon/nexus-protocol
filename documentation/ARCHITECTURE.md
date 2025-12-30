# Nexus Protocol Architecture

## System Overview

Nexus Protocol is a modular, enterprise-grade blockchain platform designed for security, scalability, and regulatory compliance. The architecture follows a layered approach with clear separation of concerns.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              FRONTEND LAYER                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Next.js   │  │  Admin UI   │  │ Governance  │  │   Mobile    │        │
│  │    dApp     │  │  Dashboard  │  │    Portal   │  │    App      │        │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘        │
└─────────┼────────────────┼────────────────┼────────────────┼────────────────┘
          │                │                │                │
          ▼                ▼                ▼                ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                               API GATEWAY                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Azure API Management / Kong                        │   │
│  │         Rate Limiting • Auth • Load Balancing • Monitoring           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                              BACKEND LAYER                                   │
│  ┌─────────────────────┐  ┌─────────────────────┐  ┌──────────────────┐    │
│  │     Go API Server   │  │   Rust CLI Tools    │  │  Python Scripts  │    │
│  │   ┌─────────────┐   │  │  ┌─────────────┐   │  │ ┌─────────────┐  │    │
│  │   │  Handlers   │   │  │  │   Deploy    │   │  │ │   Merkle    │  │    │
│  │   │  Middleware │   │  │  │   Verify    │   │  │ │  Generator  │  │    │
│  │   │   Routes    │   │  │  │   Audit     │   │  │ │  Analytics  │  │    │
│  │   └─────────────┘   │  │  └─────────────┘   │  │ └─────────────┘  │    │
│  └──────────┬──────────┘  └─────────────────────┘  └──────────────────┘    │
└─────────────┼───────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA & CACHE LAYER                                 │
│  ┌─────────────────────────────────┐  ┌─────────────────────────────────┐  │
│  │         Database                │  │           Cache                 │  │
│  │  ┌───────────┐ ┌───────────┐   │  │  ┌───────────┐ ┌───────────┐   │  │
│  │  │  SQLite   │ │ PostgreSQL│   │  │  │ go-cache  │ │   Redis   │   │  │
│  │  │  (dev)    │ │  (prod)   │   │  │  │  (dev)    │ │  (prod)   │   │  │
│  │  └───────────┘ └───────────┘   │  │  └───────────┘ └───────────┘   │  │
│  └─────────────────────────────────┘  └─────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          BLOCKCHAIN LAYER                                    │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Smart Contract Suite                            │   │
│  │  ┌───────────┐ ┌───────────┐ ┌───────────┐ ┌───────────┐           │   │
│  │  │   Core    │ │   DeFi    │ │Governance │ │ Security  │           │   │
│  │  │ Tokens    │ │ Contracts │ │ Contracts │ │ Contracts │           │   │
│  │  └───────────┘ └───────────┘ └───────────┘ └───────────┘           │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      Multi-Chain Support                             │   │
│  │     Ethereum • Arbitrum • Polygon • Base • Optimism                 │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Smart Contract Architecture

### Contract Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           CORE CONTRACTS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NexusToken (ERC-20)              NexusNFT (ERC-721A)                       │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ ERC20Upgradeable   │           │ ERC721AUpgradeable │                   │
│  │ ERC20Snapshot      │           │ ERC2981 (Royalty)  │                   │
│  │ ERC20Permit        │           │ Ownable2Step       │                   │
│  │ ERC20Votes         │           │ ReentrancyGuard    │                   │
│  │ ERC20FlashMint     │           └────────────────────┘                   │
│  │ Blocklist          │                                                     │
│  └────────────────────┘           NexusSecurityToken (ERC-1400)            │
│                                   ┌────────────────────┐                   │
│                                   │ ERC1400 Base       │                   │
│                                   │ Partitions         │                   │
│                                   │ TransferRestrict   │                   │
│                                   │ DocumentMgmt       │                   │
│                                   └────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                           DEFI CONTRACTS                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NexusStaking                     RewardsDistributor                        │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ Stake/Unstake      │           │ Streaming Rewards  │                   │
│  │ Lock Periods       │◄─────────►│ Merkle Claims      │                   │
│  │ Slashing           │           │ Multi-Token        │                   │
│  │ Delegation         │           │ Epochs             │                   │
│  │ Checkpoints        │           └────────────────────┘                   │
│  └────────────────────┘                                                     │
│                                                                              │
│  NexusVesting                     NexusAirdrop                              │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ Linear Vesting     │           │ Merkle Verification│                   │
│  │ Cliff Support      │           │ Claim Windows      │                   │
│  │ Revocable Grants   │           │ Anti-Sybil         │                   │
│  │ Beneficiary Xfer   │           │ NFT Airdrops       │                   │
│  └────────────────────┘           └────────────────────┘                   │
│                                                                              │
│  NexusPriceOracle                 NexusSettlement (DvP)                     │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ Chainlink Feed     │           │ HTLC Pattern       │                   │
│  │ Pyth Fallback      │           │ Atomic Swaps       │                   │
│  │ TWAP Calculation   │           │ Netting            │                   │
│  │ Staleness Check    │           │ Compliance Report  │                   │
│  └────────────────────┘           └────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        GOVERNANCE CONTRACTS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NexusGovernor                                                              │
│  ┌────────────────────┐                                                     │
│  │ GovernorVotes      │                                                     │
│  │ GovernorTimelock   │                                                     │
│  │ GovernorSettings   │                                                     │
│  │ GovernorCounting   │                                                     │
│  └─────────┬──────────┘                                                     │
│            │                                                                 │
│            ▼                                                                 │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ NexusTimelock      │           │ NexusMultiSig      │                   │
│  │ ──────────────     │           │ ──────────────     │                   │
│  │ 48hr Default Delay │◄─────────►│ N-of-M Sigs        │                   │
│  │ Execute/Cancel     │           │ Daily Limits       │                   │
│  │ Emergency Bypass   │           │ Tx Queue           │                   │
│  └────────────────────┘           └────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        SECURITY CONTRACTS                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NexusAccessControl                NexusKYCRegistry                         │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ ADMIN Role         │           │ Whitelist Mgmt     │                   │
│  │ OPERATOR Role      │───────────►│ Blacklist Mgmt     │                   │
│  │ COMPLIANCE Role    │           │ Jurisdiction       │                   │
│  │ PAUSER Role        │           │ Attestations       │                   │
│  │ UPGRADER Role      │           │ Expiration         │                   │
│  └────────────────────┘           └────────────────────┘                   │
│                                                                              │
│  NexusEmergency                   NexusCustody                              │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ Global Pause       │           │ Hot Wallet Ops     │                   │
│  │ Per-Contract Pause │           │ Cold Storage       │                   │
│  │ Rate Limiting      │           │ Withdrawal Queue   │                   │
│  │ Drain Protection   │           │ HSM Interface      │                   │
│  │ Recovery           │           └────────────────────┘                   │
│  └────────────────────┘                                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Contract Interactions

```
                                    ┌─────────────────┐
                                    │   User Wallet   │
                                    └────────┬────────┘
                                             │
                    ┌────────────────────────┼────────────────────────┐
                    │                        │                        │
                    ▼                        ▼                        ▼
           ┌───────────────┐        ┌───────────────┐        ┌───────────────┐
           │  NexusToken   │        │  NexusNFT     │        │ NexusStaking  │
           │    (ERC-20)   │        │  (ERC-721A)   │        │               │
           └───────┬───────┘        └───────┬───────┘        └───────┬───────┘
                   │                        │                        │
                   │                        │                        │
                   ▼                        ▼                        ▼
           ┌───────────────────────────────────────────────────────────────┐
           │                       AccessControl                           │
           │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐         │
           │  │ ADMIN   │  │OPERATOR │  │COMPLIANCE│ │ PAUSER  │         │
           │  └─────────┘  └─────────┘  └─────────┘  └─────────┘         │
           └───────────────────────────┬───────────────────────────────────┘
                                       │
                   ┌───────────────────┼───────────────────┐
                   │                   │                   │
                   ▼                   ▼                   ▼
           ┌───────────────┐   ┌───────────────┐   ┌───────────────┐
           │ KYCRegistry   │   │  Emergency    │   │   Timelock    │
           │               │   │  Controls     │   │               │
           └───────────────┘   └───────────────┘   └───────────────┘
```

## Backend Architecture

### Go API Server

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           GO API SERVER                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  cmd/server/main.go                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  - Configuration loading                                            │    │
│  │  - Dependency injection                                             │    │
│  │  - Server initialization                                            │    │
│  │  - Graceful shutdown                                                │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  internal/api/                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  routes.go          - Route definitions                             │    │
│  │  handlers/                                                          │    │
│  │    ├── auth.go      - JWT authentication                           │    │
│  │    ├── airdrop.go   - Airdrop management                           │    │
│  │    ├── staking.go   - Staking operations                           │    │
│  │    ├── governance.go- Proposal management                          │    │
│  │    ├── compliance.go- KYC/AML endpoints                            │    │
│  │    ├── admin.go     - Emergency controls                           │    │
│  │    └── analytics.go - Metrics endpoints                            │    │
│  │  middleware/                                                        │    │
│  │    ├── auth.go      - JWT validation                               │    │
│  │    ├── rbac.go      - Role-based access                            │    │
│  │    ├── ratelimit.go - Request throttling                           │    │
│  │    └── logging.go   - Request logging                              │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  internal/blockchain/                                                       │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  client.go          - Ethereum client wrapper                       │    │
│  │  contracts.go       - Contract bindings                             │    │
│  │  indexer.go         - Event indexing                                │    │
│  │  multicall.go       - Batch RPC calls                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  internal/storage/                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  repository.go      - Interface definition                          │    │
│  │  sqlite/            - SQLite implementation                         │    │
│  │  postgres/          - PostgreSQL implementation                     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  internal/cache/                                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  cache.go           - Interface definition                          │    │
│  │  memory.go          - go-cache implementation                       │    │
│  │  redis.go           - Redis implementation                          │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Data Models

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           DATA MODELS                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  User                             Airdrop                                   │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ ID: uuid           │           │ ID: uuid           │                   │
│  │ Address: string    │───────────│ Name: string       │                   │
│  │ Email: string      │           │ MerkleRoot: bytes  │                   │
│  │ Role: Role         │           │ StartTime: time    │                   │
│  │ KYCStatus: enum    │           │ EndTime: time      │                   │
│  │ CreatedAt: time    │           │ TotalAmount: big   │                   │
│  └────────────────────┘           │ ClaimedAmount: big │                   │
│                                   └────────────────────┘                   │
│                                                                              │
│  Stake                            Proposal                                  │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ ID: uuid           │           │ ID: uint256        │                   │
│  │ UserID: uuid       │           │ Title: string      │                   │
│  │ Amount: big        │           │ Description: text  │                   │
│  │ StartTime: time    │           │ ProposerID: uuid   │                   │
│  │ LockEnd: time      │           │ State: enum        │                   │
│  │ Slashed: bool      │           │ ForVotes: big      │                   │
│  └────────────────────┘           │ AgainstVotes: big  │                   │
│                                   │ StartBlock: uint   │                   │
│                                   │ EndBlock: uint     │                   │
│                                   └────────────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Infrastructure Architecture

### Container Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DEVELOPMENT PROFILE                                   │
│                     (Single Container - SQLite/go-cache)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                        nexus-api:dev                                 │   │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │   │
│  │  │   Go API        │  │    SQLite       │  │   go-cache      │     │   │
│  │  │   Server        │  │   (embedded)    │  │   (embedded)    │     │   │
│  │  └─────────────────┘  └─────────────────┘  └─────────────────┘     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                        PRODUCTION PROFILE                                    │
│                    (Multi-Container - PostgreSQL/Redis)                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐  ┌─────────────┐ │
│  │  nexus-api    │  │  nexus-api    │  │  nexus-api    │  │  nginx      │ │
│  │  (replica 1)  │  │  (replica 2)  │  │  (replica 3)  │  │  (LB)       │ │
│  └───────┬───────┘  └───────┬───────┘  └───────┬───────┘  └──────┬──────┘ │
│          │                  │                  │                  │        │
│          └──────────────────┼──────────────────┘                  │        │
│                             │                                      │        │
│          ┌──────────────────┴──────────────────┐                  │        │
│          │                                      │                  │        │
│          ▼                                      ▼                  │        │
│  ┌───────────────┐                     ┌───────────────┐          │        │
│  │  PostgreSQL   │                     │    Redis      │          │        │
│  │  (primary)    │                     │  (cluster)    │          │        │
│  └───────────────┘                     └───────────────┘          │        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Azure Container Apps Deployment

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        AZURE CONTAINER APPS                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Resource Group: rg-nexus-protocol                                          │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                     Container Apps Environment                       │   │
│  │  ┌─────────────────────────────────────────────────────────────┐   │   │
│  │  │                                                              │   │   │
│  │  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────┐   │   │   │
│  │  │  │ nexus-api     │  │ nexus-indexer │  │ nexus-worker  │   │   │   │
│  │  │  │ (http ingress)│  │ (internal)    │  │ (internal)    │   │   │   │
│  │  │  │ 0-10 replicas │  │ 1-3 replicas  │  │ 1-5 replicas  │   │   │   │
│  │  │  └───────────────┘  └───────────────┘  └───────────────┘   │   │   │
│  │  │                                                              │   │   │
│  │  └─────────────────────────────────────────────────────────────┘   │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────┐  ┌─────────────────────────┐          │   │
│  │  │ Azure Database for      │  │ Azure Cache for Redis   │          │   │
│  │  │ PostgreSQL (Flexible)   │  │ (Basic/Standard)        │          │   │
│  │  └─────────────────────────┘  └─────────────────────────┘          │   │
│  │                                                                      │   │
│  │  ┌─────────────────────────┐  ┌─────────────────────────┐          │   │
│  │  │ Azure Key Vault         │  │ Azure Monitor           │          │   │
│  │  │ (secrets management)    │  │ (logging/metrics)       │          │   │
│  │  └─────────────────────────┘  └─────────────────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Security Architecture

### Defense in Depth

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LAYER 1: NETWORK                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  WAF • DDoS Protection • IP Filtering • TLS 1.3                     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│                           LAYER 2: APPLICATION                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  JWT Auth • RBAC • Rate Limiting • Input Validation • CORS          │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│                           LAYER 3: SMART CONTRACT                            │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Access Control • Reentrancy Guard • Pausable • Timelock • MultiSig │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────────────────────┤
│                           LAYER 4: MONITORING                                │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │  Tenderly Alerts • Forta Bots • Grafana Dashboards • PagerDuty      │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Management Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KEY MANAGEMENT ARCHITECTURE                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐                                                        │
│  │  Admin Actions  │                                                        │
│  │  (Governance)   │                                                        │
│  └────────┬────────┘                                                        │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐     48hr delay      ┌─────────────────┐               │
│  │    Timelock     │ ──────────────────► │    Execution    │               │
│  │   Controller    │                      │                 │               │
│  └────────┬────────┘                      └────────┬────────┘               │
│           │                                        │                        │
│           │ Critical ops require                   │                        │
│           ▼                                        ▼                        │
│  ┌─────────────────┐                      ┌─────────────────┐               │
│  │    MultiSig     │                      │   Hot Wallet    │               │
│  │    (3-of-5)     │                      │   (Ops Only)    │               │
│  └────────┬────────┘                      └─────────────────┘               │
│           │                                                                  │
│           │ For treasury/upgrades                                           │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │   Cold Storage  │                                                        │
│  │  (HSM/Hardware) │                                                        │
│  └─────────────────┘                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Deployment Environments

| Environment | Database | Cache | Containers | RPC | Use Case |
|-------------|----------|-------|------------|-----|----------|
| **local** | SQLite | go-cache | 1 | Anvil | Development |
| **dev** | SQLite | go-cache | 1 | Sepolia | Integration testing |
| **demo** | SQLite | go-cache | 1 | Sepolia | Portfolio demos |
| **staging** | PostgreSQL | Redis | 3-4 | Sepolia | Pre-production |
| **production** | PostgreSQL | Redis | 3-10 | Mainnet | Production |

## Technology Stack

### Smart Contracts
- **Language**: Solidity 0.8.24
- **Framework**: Foundry (forge, cast, anvil)
- **Libraries**: OpenZeppelin, ERC721A, Chainlink
- **Testing**: Foundry Test, Echidna, Certora

### Backend
- **Language**: Go 1.21+
- **Framework**: Gin
- **Database**: SQLite / PostgreSQL
- **Cache**: go-cache / Redis
- **Auth**: JWT (RS256)

### Frontend
- **Framework**: Next.js 14
- **State**: Zustand
- **Web3**: wagmi, viem
- **UI**: Tailwind CSS, shadcn/ui

### Infrastructure
- **Containers**: Docker
- **Orchestration**: Kubernetes / Azure Container Apps
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Monitoring**: Tenderly, Grafana, OpenTelemetry

### Security Tools
- **Static Analysis**: Slither, Aderyn
- **Fuzzing**: Echidna
- **Formal Verification**: Certora
- **Runtime**: Tenderly, Forta

## Design Decisions

### Why UUPS over Transparent Proxy?
- Lower gas costs for users (no proxy admin checks per call)
- Cleaner upgrade logic in implementation
- Better suited for governance-controlled upgrades

### Why ERC721A over ERC721?
- 90%+ gas savings on batch mints
- Critical for NFT drop success
- No tradeoffs for single mints

### Why SQLite Option?
- Zero external dependencies for demos
- Instant setup for developers
- Sufficient for portfolio demonstrations
- Easy migration path to PostgreSQL

### Why Streaming Rewards?
- Fairer distribution (per-second accrual)
- Reduced gas vs. epoch-based claiming
- Better UX with real-time balance updates
