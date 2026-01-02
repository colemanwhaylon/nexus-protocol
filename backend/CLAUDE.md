# Backend - Go Conventions & Patterns

> **Scope**: These conventions apply to all Go code in the `backend/` directory.
> **Inherits**: All rules from project root `CLAUDE.md` (SOLID principles, architecture layers, etc.)

---

## Go Version & Modules

- **Go Version**: 1.21+
- **Module Path**: `github.com/colemanwhaylon/nexus-protocol/backend`
- **Dependencies**: Managed via `go.mod`, vendor not committed

---

## Package Structure

```
backend/
├── cmd/
│   └── server/
│       └── main.go              # Entry point only - DI wiring, server start
├── internal/                     # Private packages (not importable externally)
│   ├── config/
│   │   └── config.go            # Environment loading, validation
│   ├── database/
│   │   ├── postgres.go          # Connection pool, health checks
│   │   └── migrations.go        # Schema migrations
│   ├── handlers/                # HTTP handlers (Gin)
│   │   ├── kyc.go
│   │   ├── nft.go
│   │   ├── governance.go
│   │   ├── staking.go
│   │   ├── token.go
│   │   └── health.go
│   ├── repository/              # Interface definitions ONLY
│   │   ├── kyc.go               # KYCRepository interface
│   │   ├── nft.go               # NFTRepository interface
│   │   ├── governance.go        # GovernanceRepository interface
│   │   ├── staking.go           # StakingRepository interface
│   │   ├── token.go             # TokenRepository interface
│   │   ├── audit.go             # AuditRepository interface
│   │   └── errors.go            # Domain errors
│   ├── services/                # Business logic (optional layer)
│   │   └── ...
│   ├── storage/                 # Repository implementations
│   │   ├── postgres/            # PostgreSQL implementations
│   │   │   ├── kyc.go
│   │   │   ├── nft.go
│   │   │   └── ...
│   │   └── memory/              # In-memory implementations (testing)
│   │       ├── kyc.go
│   │       └── ...
│   └── providers/               # External service adapters
│       ├── interfaces.go        # Provider interfaces
│       ├── sumsub/              # Sumsub KYC adapter
│       ├── stripe/              # Stripe payment adapter
│       └── registry.go          # Provider registry
├── pkg/                         # Public packages (can be imported)
│   └── types/                   # Shared types, DTOs
└── tests/                       # Integration tests
    └── integration/
```

---

## Naming Conventions

### Files

| Type | Convention | Example |
|------|------------|---------|
| Package | lowercase, single word | `handlers`, `repository` |
| Interface file | noun | `repository/kyc.go` |
| Implementation file | noun | `storage/postgres/kyc.go` |
| Test file | `*_test.go` | `kyc_test.go` |
| Integration test | `*_integration_test.go` | `kyc_integration_test.go` |

### Types

```go
// Interfaces - noun, describes capability
type KYCRepository interface { ... }
type PaymentProvider interface { ... }

// Structs implementing interfaces - prefix with implementation type
type PostgresKYCRepo struct { ... }
type MemoryKYCRepo struct { ... }
type SumsubProvider struct { ... }

// Request/Response types - suffix with Request/Response
type CreateKYCRequest struct { ... }
type CreateKYCResponse struct { ... }

// Domain models - plain noun
type KYCRegistration struct { ... }
type Proposal struct { ... }
```

### Functions

```go
// Constructors - NewXxx
func NewKYCHandler(repo repository.KYCRepository) *KYCHandler

// Interface methods - verb + noun
func (r *PostgresKYCRepo) CreateRegistration(ctx context.Context, ...) error
func (r *PostgresKYCRepo) GetRegistration(ctx context.Context, ...) (*KYCRegistration, error)
func (r *PostgresKYCRepo) UpdateStatus(ctx context.Context, ...) error
func (r *PostgresKYCRepo) DeleteRegistration(ctx context.Context, ...) error

// HTTP handlers - HTTP verb implied
func (h *KYCHandler) Create(c *gin.Context)   // POST /kyc
func (h *KYCHandler) Get(c *gin.Context)      // GET /kyc/:id
func (h *KYCHandler) Update(c *gin.Context)   // PUT /kyc/:id
func (h *KYCHandler) Delete(c *gin.Context)   // DELETE /kyc/:id
func (h *KYCHandler) List(c *gin.Context)     // GET /kyc
```

---

## Interface Definition Pattern

All interfaces go in `internal/repository/`:

```go
// internal/repository/kyc.go
package repository

import (
    "context"
    "time"
)

// KYCRepository defines the contract for KYC data operations
type KYCRepository interface {
    // Registration CRUD
    CreateRegistration(ctx context.Context, reg *KYCRegistration) error
    GetRegistration(ctx context.Context, address string) (*KYCRegistration, error)
    UpdateRegistration(ctx context.Context, reg *KYCRegistration) error
    ListRegistrations(ctx context.Context, filter KYCFilter, page Pagination) ([]*KYCRegistration, int64, error)

    // Whitelist operations
    AddToWhitelist(ctx context.Context, address string, addedBy string, reason string) error
    RemoveFromWhitelist(ctx context.Context, address string) error
    IsWhitelisted(ctx context.Context, address string) (bool, error)

    // Blacklist operations
    AddToBlacklist(ctx context.Context, address string, addedBy string, reason string) error
    RemoveFromBlacklist(ctx context.Context, address string) error
    IsBlacklisted(ctx context.Context, address string) (bool, error)

    // Compliance officers
    AddOfficer(ctx context.Context, address string, addedBy string) error
    RemoveOfficer(ctx context.Context, address string) error
    IsOfficer(ctx context.Context, address string) (bool, error)
    ListOfficers(ctx context.Context) ([]string, error)

    // Jurisdictions
    GetJurisdiction(ctx context.Context, code string) (*Jurisdiction, error)
    ListJurisdictions(ctx context.Context) ([]*Jurisdiction, error)
}

// KYCRegistration represents a KYC registration record
type KYCRegistration struct {
    ID              string     `json:"id" db:"id"`
    Address         string     `json:"address" db:"address"`
    Status          string     `json:"status" db:"status"`
    Level           int        `json:"level" db:"level"`
    Jurisdiction    string     `json:"jurisdiction" db:"jurisdiction"`
    VerifiedAt      *time.Time `json:"verified_at,omitempty" db:"verified_at"`
    ExpiresAt       *time.Time `json:"expires_at,omitempty" db:"expires_at"`
    RejectionReason string     `json:"rejection_reason,omitempty" db:"rejection_reason"`
    RiskScore       int        `json:"risk_score" db:"risk_score"`
    ReviewedBy      string     `json:"reviewed_by,omitempty" db:"reviewed_by"`
    CreatedAt       time.Time  `json:"created_at" db:"created_at"`
    UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// KYCFilter defines filtering options for listing registrations
type KYCFilter struct {
    Status       string
    Jurisdiction string
    MinRiskScore *int
    MaxRiskScore *int
}

// Pagination defines pagination parameters
type Pagination struct {
    Page     int
    PageSize int
}
```

---

## Repository Implementation Pattern

PostgreSQL implementations go in `internal/storage/postgres/`:

```go
// internal/storage/postgres/kyc.go
package postgres

import (
    "context"
    "database/sql"
    "errors"
    "fmt"

    "github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresKYCRepo implements KYCRepository
var _ repository.KYCRepository = (*PostgresKYCRepo)(nil)

// PostgresKYCRepo implements KYCRepository using PostgreSQL
type PostgresKYCRepo struct {
    db *sql.DB
}

// NewPostgresKYCRepo creates a new PostgreSQL KYC repository
func NewPostgresKYCRepo(db *sql.DB) *PostgresKYCRepo {
    return &PostgresKYCRepo{db: db}
}

// CreateRegistration creates a new KYC registration
func (r *PostgresKYCRepo) CreateRegistration(ctx context.Context, reg *repository.KYCRegistration) error {
    query := `
        INSERT INTO kyc_registrations (address, status, level, jurisdiction, risk_score)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, created_at, updated_at
    `

    err := r.db.QueryRowContext(ctx, query,
        reg.Address,
        reg.Status,
        reg.Level,
        reg.Jurisdiction,
        reg.RiskScore,
    ).Scan(&reg.ID, &reg.CreatedAt, &reg.UpdatedAt)

    if err != nil {
        // Check for unique constraint violation
        if isUniqueViolation(err) {
            return repository.ErrKYCAlreadyExists
        }
        return fmt.Errorf("creating kyc registration: %w", err)
    }

    return nil
}

// GetRegistration retrieves a KYC registration by address
func (r *PostgresKYCRepo) GetRegistration(ctx context.Context, address string) (*repository.KYCRegistration, error) {
    query := `
        SELECT id, address, status, level, jurisdiction, verified_at, expires_at,
               rejection_reason, risk_score, reviewed_by, created_at, updated_at
        FROM kyc_registrations
        WHERE address = $1
    `

    reg := &repository.KYCRegistration{}
    err := r.db.QueryRowContext(ctx, query, address).Scan(
        &reg.ID,
        &reg.Address,
        &reg.Status,
        &reg.Level,
        &reg.Jurisdiction,
        &reg.VerifiedAt,
        &reg.ExpiresAt,
        &reg.RejectionReason,
        &reg.RiskScore,
        &reg.ReviewedBy,
        &reg.CreatedAt,
        &reg.UpdatedAt,
    )

    if err != nil {
        if errors.Is(err, sql.ErrNoRows) {
            return nil, repository.ErrKYCNotFound
        }
        return nil, fmt.Errorf("getting kyc registration for %s: %w", address, err)
    }

    return reg, nil
}

// IsWhitelisted checks if an address is whitelisted
func (r *PostgresKYCRepo) IsWhitelisted(ctx context.Context, address string) (bool, error) {
    query := `SELECT EXISTS(SELECT 1 FROM whitelist WHERE address = $1)`

    var exists bool
    err := r.db.QueryRowContext(ctx, query, address).Scan(&exists)
    if err != nil {
        return false, fmt.Errorf("checking whitelist for %s: %w", address, err)
    }

    return exists, nil
}

// ... implement remaining interface methods
```

---

## Handler Pattern

Handlers are thin HTTP adapters that delegate to repositories/services:

```go
// internal/handlers/kyc.go
package handlers

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"

    "github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// KYCHandler handles KYC-related HTTP endpoints
type KYCHandler struct {
    repo   repository.KYCRepository
    audit  repository.AuditRepository
    logger *zap.Logger
}

// NewKYCHandler creates a new KYC handler with injected dependencies
func NewKYCHandler(
    repo repository.KYCRepository,
    audit repository.AuditRepository,
    logger *zap.Logger,
) *KYCHandler {
    return &KYCHandler{
        repo:   repo,
        audit:  audit,
        logger: logger,
    }
}

// Approve handles POST /api/v1/kyc/:address/approve
func (h *KYCHandler) Approve(c *gin.Context) {
    address := c.Param("address")
    officerAddress := c.GetString("user_address") // From auth middleware

    // Validate address format
    if !isValidAddress(address) {
        c.JSON(http.StatusBadRequest, gin.H{
            "success": false,
            "error":   "invalid ethereum address format",
        })
        return
    }

    // Check if registration exists
    reg, err := h.repo.GetRegistration(c.Request.Context(), address)
    if err != nil {
        if errors.Is(err, repository.ErrKYCNotFound) {
            c.JSON(http.StatusNotFound, gin.H{
                "success": false,
                "error":   "kyc registration not found",
            })
            return
        }
        h.logger.Error("failed to get registration", zap.Error(err))
        c.JSON(http.StatusInternalServerError, gin.H{
            "success": false,
            "error":   "internal server error",
        })
        return
    }

    // Add to whitelist
    if err := h.repo.AddToWhitelist(c.Request.Context(), address, officerAddress, "KYC approved"); err != nil {
        h.logger.Error("failed to add to whitelist", zap.Error(err))
        c.JSON(http.StatusInternalServerError, gin.H{
            "success": false,
            "error":   "failed to approve kyc",
        })
        return
    }

    // Log audit entry
    h.audit.Log(c.Request.Context(), repository.AuditEntry{
        Action:  "kyc_approved",
        Actor:   officerAddress,
        Subject: address,
        Details: "KYC registration approved",
    })

    h.logger.Info("kyc approved",
        zap.String("address", address),
        zap.String("approved_by", officerAddress),
    )

    c.JSON(http.StatusOK, gin.H{
        "success": true,
        "message": "KYC approved successfully",
    })
}
```

---

## Dependency Injection in main.go

```go
// cmd/server/main.go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"

    "github.com/gin-gonic/gin"
    "go.uber.org/zap"

    "github.com/colemanwhaylon/nexus-protocol/backend/internal/config"
    "github.com/colemanwhaylon/nexus-protocol/backend/internal/database"
    "github.com/colemanwhaylon/nexus-protocol/backend/internal/handlers"
    "github.com/colemanwhaylon/nexus-protocol/backend/internal/storage/postgres"
)

func main() {
    // Load configuration
    cfg, err := config.Load()
    if err != nil {
        log.Fatalf("failed to load config: %v", err)
    }

    // Initialize logger
    logger, _ := zap.NewProduction()
    defer logger.Sync()

    // Connect to database
    db, err := database.NewPostgresPool(cfg.DatabaseURL)
    if err != nil {
        logger.Fatal("failed to connect to database", zap.Error(err))
    }
    defer db.Close()

    // Run migrations
    if err := database.RunMigrations(db); err != nil {
        logger.Fatal("failed to run migrations", zap.Error(err))
    }

    // Create repositories (DEPENDENCY INJECTION)
    kycRepo := postgres.NewPostgresKYCRepo(db)
    nftRepo := postgres.NewPostgresNFTRepo(db)
    govRepo := postgres.NewPostgresGovernanceRepo(db)
    stakingRepo := postgres.NewPostgresStakingRepo(db)
    tokenRepo := postgres.NewPostgresTokenRepo(db)
    auditRepo := postgres.NewPostgresAuditRepo(db)

    // Create handlers with injected dependencies
    kycHandler := handlers.NewKYCHandler(kycRepo, auditRepo, logger)
    nftHandler := handlers.NewNFTHandler(nftRepo, auditRepo, logger)
    govHandler := handlers.NewGovernanceHandler(govRepo, auditRepo, logger)
    stakingHandler := handlers.NewStakingHandler(stakingRepo, logger)
    tokenHandler := handlers.NewTokenHandler(tokenRepo, logger)
    healthHandler := handlers.NewHealthHandler(db, logger)

    // Setup router
    router := gin.Default()

    // Register routes
    api := router.Group("/api/v1")
    {
        // KYC routes
        kyc := api.Group("/kyc")
        {
            kyc.POST("", kycHandler.Create)
            kyc.GET("/:address", kycHandler.Get)
            kyc.POST("/:address/approve", kycHandler.Approve)
            kyc.POST("/:address/reject", kycHandler.Reject)
            kyc.GET("/whitelist/:address", kycHandler.CheckWhitelist)
        }

        // NFT routes
        nft := api.Group("/nft")
        {
            nft.POST("/mint", nftHandler.Mint)
            nft.GET("/:tokenId", nftHandler.Get)
            nft.GET("/owner/:address", nftHandler.GetByOwner)
            nft.POST("/transfer", nftHandler.Transfer)
        }

        // ... more routes
    }

    // Health check
    router.GET("/health", healthHandler.Check)

    // Start server with graceful shutdown
    srv := &http.Server{
        Addr:    ":" + cfg.Port,
        Handler: router,
    }

    go func() {
        logger.Info("starting server", zap.String("port", cfg.Port))
        if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            logger.Fatal("server failed", zap.Error(err))
        }
    }()

    // Wait for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    <-quit

    logger.Info("shutting down server...")

    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        logger.Fatal("server forced to shutdown", zap.Error(err))
    }

    logger.Info("server exited")
}
```

---

## Context Usage

Always pass `context.Context` as the first parameter to repository methods:

```go
// RIGHT
func (r *PostgresKYCRepo) GetRegistration(ctx context.Context, address string) (*KYCRegistration, error)

// WRONG
func (r *PostgresKYCRepo) GetRegistration(address string) (*KYCRegistration, error)
```

Use context for:
- Request cancellation
- Timeouts
- Request-scoped values (user ID, trace ID)

---

## Logging

Use structured logging with `zap`:

```go
// RIGHT - structured fields
h.logger.Info("kyc approved",
    zap.String("address", address),
    zap.String("approved_by", officer),
    zap.Duration("processing_time", time.Since(start)),
)

// WRONG - string formatting
h.logger.Info(fmt.Sprintf("kyc approved for %s by %s", address, officer))
```

Log levels:
- `Debug` - Development only, verbose
- `Info` - Normal operations, audit trail
- `Warn` - Recoverable issues, degraded performance
- `Error` - Failures that need attention
- `Fatal` - Unrecoverable, application exits

---

## Testing

### Unit Test Example

```go
// internal/handlers/kyc_test.go
package handlers_test

import (
    "net/http"
    "net/http/httptest"
    "testing"

    "github.com/gin-gonic/gin"
    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/mock"
    "go.uber.org/zap"

    "github.com/colemanwhaylon/nexus-protocol/backend/internal/handlers"
    "github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

type MockKYCRepo struct {
    mock.Mock
}

func (m *MockKYCRepo) IsWhitelisted(ctx context.Context, address string) (bool, error) {
    args := m.Called(ctx, address)
    return args.Bool(0), args.Error(1)
}

// ... implement other interface methods

func TestKYCHandler_CheckWhitelist(t *testing.T) {
    gin.SetMode(gin.TestMode)

    mockRepo := new(MockKYCRepo)
    mockAudit := new(MockAuditRepo)
    logger := zap.NewNop()

    handler := handlers.NewKYCHandler(mockRepo, mockAudit, logger)

    t.Run("returns true for whitelisted address", func(t *testing.T) {
        mockRepo.On("IsWhitelisted", mock.Anything, "0x1234...").Return(true, nil)

        w := httptest.NewRecorder()
        c, _ := gin.CreateTestContext(w)
        c.Params = gin.Params{{Key: "address", Value: "0x1234..."}}

        handler.CheckWhitelist(c)

        assert.Equal(t, http.StatusOK, w.Code)
        mockRepo.AssertExpectations(t)
    })
}
```

### Integration Test Example

```go
// tests/integration/kyc_integration_test.go
package integration_test

import (
    "context"
    "testing"

    "github.com/stretchr/testify/require"
    "github.com/testcontainers/testcontainers-go"
    "github.com/testcontainers/testcontainers-go/modules/postgres"

    pgStorage "github.com/colemanwhaylon/nexus-protocol/backend/internal/storage/postgres"
)

func TestPostgresKYCRepo_Integration(t *testing.T) {
    if testing.Short() {
        t.Skip("skipping integration test")
    }

    ctx := context.Background()

    // Start PostgreSQL container
    pgContainer, err := postgres.RunContainer(ctx,
        testcontainers.WithImage("postgres:15"),
        postgres.WithDatabase("nexus_test"),
        postgres.WithUsername("test"),
        postgres.WithPassword("test"),
    )
    require.NoError(t, err)
    defer pgContainer.Terminate(ctx)

    // Get connection string
    connStr, err := pgContainer.ConnectionString(ctx)
    require.NoError(t, err)

    // Create repo
    db, err := sql.Open("postgres", connStr)
    require.NoError(t, err)
    defer db.Close()

    repo := pgStorage.NewPostgresKYCRepo(db)

    t.Run("create and retrieve registration", func(t *testing.T) {
        reg := &repository.KYCRegistration{
            Address:      "0x1234567890123456789012345678901234567890",
            Status:       "pending",
            Jurisdiction: "US",
        }

        err := repo.CreateRegistration(ctx, reg)
        require.NoError(t, err)
        require.NotEmpty(t, reg.ID)

        retrieved, err := repo.GetRegistration(ctx, reg.Address)
        require.NoError(t, err)
        require.Equal(t, reg.Address, retrieved.Address)
    })
}
```

---

## Common Mistakes to Avoid

```go
// 1. WRONG: Using concrete type instead of interface
type KYCHandler struct {
    repo *postgres.PostgresKYCRepo  // WRONG
}

// RIGHT: Use interface
type KYCHandler struct {
    repo repository.KYCRepository  // RIGHT
}

// 2. WRONG: Returning generic error
if err != nil {
    return errors.New("something went wrong")  // WRONG
}

// RIGHT: Return domain error with context
if err != nil {
    return fmt.Errorf("creating registration for %s: %w", address, err)  // RIGHT
}

// 3. WRONG: Ignoring context
func (r *Repo) Get(address string) (*Data, error) {  // WRONG - no context
    r.db.Query(...)
}

// RIGHT: Pass context
func (r *Repo) Get(ctx context.Context, address string) (*Data, error) {  // RIGHT
    r.db.QueryContext(ctx, ...)
}

// 4. WRONG: Business logic in handler
func (h *Handler) Approve(c *gin.Context) {
    // 50 lines of business logic HERE  // WRONG
}

// RIGHT: Handler delegates to repository/service
func (h *Handler) Approve(c *gin.Context) {
    // Parse request
    // Call h.repo.Approve(ctx, ...)
    // Return response
}
```

---

## Quick Reference

| Task | Location |
|------|----------|
| Define interface | `internal/repository/*.go` |
| Implement interface (Postgres) | `internal/storage/postgres/*.go` |
| Implement interface (Memory) | `internal/storage/memory/*.go` |
| HTTP handlers | `internal/handlers/*.go` |
| Business logic | `internal/services/*.go` |
| Configuration | `internal/config/config.go` |
| Database connection | `internal/database/postgres.go` |
| Entry point & DI | `cmd/server/main.go` |
| Unit tests | `*_test.go` (same directory) |
| Integration tests | `tests/integration/*.go` |
