# Nexus Protocol - Claude Code Instructions

> **Purpose**: This document defines architectural standards, coding conventions, and SOLID principles that ALL code contributions must follow. Claude MUST read and apply these rules before writing any code.

---

## Project Overview

Nexus Protocol is a production-grade DeFi + NFT + Enterprise Tokenization platform. It demonstrates institutional-quality smart contract security, blockchain infrastructure, and full-stack development.

**Repository**: `github.com/colemanwhaylon/nexus-protocol`

---

## SOLID Principles (MANDATORY)

All code in this project MUST adhere to SOLID principles. Violations will require refactoring.

### S - Single Responsibility Principle

```
WRONG:
┌─────────────────────────────────────────────────────────────┐
│ type KYCHandler struct {                                    │
│     db *sql.DB           // Handles DB directly             │
│     cache *redis.Client  // Handles cache directly          │
│     logger *zap.Logger                                      │
│ }                                                           │
│                                                             │
│ func (h *KYCHandler) Approve(c *gin.Context) {              │
│     // Validation logic HERE                                │
│     // Database logic HERE                                  │
│     // Cache logic HERE                                     │
│     // Notification logic HERE                              │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

RIGHT:
┌─────────────────────────────────────────────────────────────┐
│ type KYCHandler struct {                                    │
│     repo      KYCRepository      // Abstracts data access   │
│     validator KYCValidator       // Abstracts validation    │
│     notifier  NotificationService // Abstracts notifications│
│     logger    *zap.Logger                                   │
│ }                                                           │
│                                                             │
│ func (h *KYCHandler) Approve(c *gin.Context) {              │
│     // Handler ONLY orchestrates, doesn't implement         │
│     if err := h.validator.ValidateApproval(req); err != nil │
│     h.repo.AddToWhitelist(ctx, address)                     │
│     h.notifier.NotifyKYCApproved(address)                   │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### O - Open/Closed Principle

Code must be **open for extension, closed for modification**.

```
WRONG: Adding a new KYC provider requires modifying existing code
RIGHT: Adding a new KYC provider only requires implementing an interface
```

### L - Liskov Substitution Principle

Any implementation of an interface must be substitutable without breaking the system.

```go
// If PostgresKYCRepo implements KYCRepository,
// swapping it with MemoryKYCRepo must not break any handler
var repo KYCRepository = NewPostgresKYCRepo(db)  // Production
var repo KYCRepository = NewMemoryKYCRepo()       // Testing
// Handler works identically with both
```

### I - Interface Segregation Principle

Prefer small, focused interfaces over large ones.

```
WRONG:
┌─────────────────────────────────────────────────────────────┐
│ type Repository interface {                                 │
│     CreateKYC() / GetKYC() / UpdateKYC()                   │
│     CreateNFT() / GetNFT() / TransferNFT()                 │
│     CreateProposal() / Vote() / Execute()                  │
│     // 50+ methods in one interface                        │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

RIGHT:
┌─────────────────────────────────────────────────────────────┐
│ type KYCRepository interface {                              │
│     CreateRegistration() / GetRegistration() / ...          │
│ }                                                           │
│ type NFTRepository interface {                              │
│     MintToken() / GetToken() / TransferToken() / ...        │
│ }                                                           │
│ type GovernanceRepository interface {                       │
│     CreateProposal() / CastVote() / ...                     │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

### D - Dependency Inversion Principle

High-level modules must not depend on low-level modules. Both must depend on abstractions.

```
WRONG:
┌─────────────────────────────────────────────────────────────┐
│ Handler → PostgreSQL (direct dependency)                    │
│                                                             │
│ type KYCHandler struct {                                    │
│     db *sql.DB  // Concrete type                           │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

RIGHT:
┌─────────────────────────────────────────────────────────────┐
│ Handler → Interface ← PostgreSQL                            │
│                                                             │
│ type KYCHandler struct {                                    │
│     repo KYCRepository  // Interface type                   │
│ }                                                           │
│                                                             │
│ // Injection at startup:                                    │
│ handler := NewKYCHandler(NewPostgresKYCRepo(db))           │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                      │
│  handlers/*.go - HTTP handlers, request/response parsing     │
│  Only orchestrates, no business logic                        │
├─────────────────────────────────────────────────────────────┤
│                       SERVICE LAYER                          │
│  services/*.go - Business logic, validation, workflows       │
│  Depends on repository interfaces, not implementations       │
├─────────────────────────────────────────────────────────────┤
│                      REPOSITORY LAYER                        │
│  repository/*.go - Interface definitions (contracts)         │
│  storage/postgres/*.go - PostgreSQL implementations          │
│  storage/memory/*.go - In-memory implementations (testing)   │
├─────────────────────────────────────────────────────────────┤
│                        DATA LAYER                            │
│  database/*.go - Connection pooling, migrations              │
│  PostgreSQL, Redis (production) / SQLite, go-cache (dev)     │
└─────────────────────────────────────────────────────────────┘
```

---

## External Service Integration Pattern

When integrating ANY external service (Sumsub, Stripe, Chainlink, etc.), ALWAYS use the Provider pattern:

```go
// 1. Define provider interface
type KYCProvider interface {
    CreateApplicant(ctx context.Context, req CreateApplicantRequest) (*Applicant, error)
    GetStatus(ctx context.Context, applicantID string) (*Status, error)
    Name() string
    HealthCheck(ctx context.Context) error
}

// 2. Implement for each provider
type SumsubProvider struct { ... }
type JumioProvider struct { ... }
type OnfidoProvider struct { ... }

// 3. Use provider registry for runtime switching
type ProviderRegistry interface {
    GetActiveKYCProvider(ctx context.Context) (KYCProvider, error)
    Failover(ctx context.Context, failed string, reason string) error
}

// 4. Provider selection via database, not code
// UPDATE providers SET is_active=true WHERE name='jumio';
```

**Rule**: NEVER hardcode external service calls. Always abstract behind interfaces for:
- Runtime provider switching
- Automatic failover on outages
- Easy testing with mocks
- Future provider additions without code changes

---

## Database Conventions

### All Data in PostgreSQL

- **NO in-memory maps** for persistent data
- Mock/demo data lives in database seed files
- Use `init-db.sql` for schema, `seed-data.sql` for demo data

### Configuration in Database

Anything that might change without a deploy goes in the database:

| Config Type | Table | Example |
|-------------|-------|---------|
| Feature flags | `feature_flags` | `enable_staking = true` |
| Pricing | `pricing` | `kyc_fee_usd = 15.00` |
| Providers | `providers` | `active_kyc_provider = 'sumsub'` |
| Rate limits | `rate_limits` | `api_requests_per_min = 100` |

### Transactions

Always use transactions for multi-step operations:

```go
func (r *PostgresKYCRepo) ApproveWithAudit(ctx context.Context, address string, officer string) error {
    tx, err := r.db.BeginTx(ctx, nil)
    if err != nil {
        return err
    }
    defer tx.Rollback()

    // Step 1: Add to whitelist
    if err := r.addToWhitelistTx(ctx, tx, address); err != nil {
        return err
    }

    // Step 2: Log audit entry
    if err := r.logAuditTx(ctx, tx, "kyc_approved", officer, address); err != nil {
        return err
    }

    return tx.Commit()
}
```

---

## Error Handling

### Domain Errors

Define domain-specific errors, not generic ones:

```go
// WRONG
return errors.New("not found")

// RIGHT
var (
    ErrKYCNotFound       = errors.New("kyc registration not found")
    ErrKYCAlreadyExists  = errors.New("kyc registration already exists")
    ErrKYCExpired        = errors.New("kyc registration has expired")
    ErrAddressBlacklisted = errors.New("address is blacklisted")
)
```

### Error Wrapping

Always wrap errors with context:

```go
if err := r.db.QueryRow(query, address).Scan(&result); err != nil {
    if errors.Is(err, sql.ErrNoRows) {
        return nil, ErrKYCNotFound
    }
    return nil, fmt.Errorf("querying kyc registration for %s: %w", address, err)
}
```

---

## Testing Requirements

### Every Repository Needs

1. **Unit tests** with mock database
2. **Integration tests** with real PostgreSQL (testcontainers)
3. **Interface compliance tests** (ensure all methods are implemented)

### Test File Naming

```
kyc.go           → kyc_test.go (unit tests)
kyc.go           → kyc_integration_test.go (integration tests)
```

### Mock Generation

Use interfaces for easy mocking:

```go
// In tests, create mock implementation
type MockKYCRepo struct {
    mock.Mock
}

func (m *MockKYCRepo) IsWhitelisted(ctx context.Context, addr string) (bool, error) {
    args := m.Called(ctx, addr)
    return args.Bool(0), args.Error(1)
}
```

---

## Multi-Machine Development

This project uses 3 machines for parallel development:

| Machine | IP | User | Domains |
|---------|-----|------|---------|
| M1 (Controller) | 192.168.1.41 | whaylon | KYC, Staking, Frontend, Orchestration |
| M2 (Worker) | 192.168.1.109 | aiagent | NFT, Token, Database, Docker |
| M3 (Worker) | 192.168.1.224 | aiagent | Governance, Audit, Contracts, Docs |

### Branch Strategy

- `main` - Production-ready code
- `develop` - Integration branch
- `feature/m1-*` - M1 feature branches
- `feature/m2-*` - M2 feature branches
- `feature/m3-*` - M3 feature branches

### File Ownership

Each machine owns specific domains. Do not modify files owned by another machine without coordination.

---

## Code Review Checklist

Before submitting ANY code, verify:

- [ ] SOLID principles followed (no violations)
- [ ] Interfaces used for external dependencies
- [ ] Database used for persistent data (no in-memory maps)
- [ ] Configuration stored in database (not hardcoded)
- [ ] Errors are domain-specific and wrapped
- [ ] Tests written (unit + integration)
- [ ] No direct SQL in handlers (use repository layer)
- [ ] Transactions used for multi-step operations
- [ ] Provider pattern used for external services

---

## Forbidden Patterns

**NEVER do these:**

1. ❌ `map[string]*Data` for persistent storage in handlers
2. ❌ Direct database calls in HTTP handlers
3. ❌ Hardcoded external service URLs/keys
4. ❌ `time.Sleep()` to simulate async operations
5. ❌ `console.log()` / `fmt.Println()` for important events (use structured logging)
6. ❌ Hardcoded prices, fees, or configuration values
7. ❌ Giant interfaces with 20+ methods
8. ❌ Concrete types in struct fields (use interfaces)
9. ❌ Ignoring errors with `_`
10. ❌ Global variables for state

---

## Directory Structure

```
nexus-protocol/
├── backend/
│   ├── cmd/server/main.go       # Entry point, DI wiring
│   ├── internal/
│   │   ├── config/              # Configuration loading
│   │   ├── database/            # DB connection, migrations
│   │   ├── handlers/            # HTTP handlers (thin layer)
│   │   ├── repository/          # Interface definitions
│   │   ├── services/            # Business logic
│   │   ├── storage/
│   │   │   ├── postgres/        # PostgreSQL implementations
│   │   │   └── memory/          # In-memory implementations (testing)
│   │   └── providers/           # External service interfaces
│   │       ├── kyc/             # Sumsub, Jumio adapters
│   │       ├── payment/         # Stripe, Coinbase adapters
│   │       └── oracle/          # Chainlink adapter
│   └── tests/                   # Integration tests
├── contracts/                   # Solidity smart contracts
├── frontend/                    # Next.js frontend
├── infrastructure/              # Docker, K8s, Terraform
└── documentation/               # All documentation
```

---

## When In Doubt

1. **Ask**: Use the interface pattern
2. **Store**: Put it in the database
3. **Configure**: Make it changeable without deploy
4. **Test**: Write tests before implementation
5. **Abstract**: If it's external, wrap it in an interface
