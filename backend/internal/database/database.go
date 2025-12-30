package database

import (
	"database/sql"
	"fmt"
	"time"

	_ "github.com/lib/pq"           // PostgreSQL driver
	_ "github.com/mattn/go-sqlite3" // SQLite driver
	"go.uber.org/zap"
)

// Config holds database configuration
type Config struct {
	Driver   string
	Host     string
	Port     int
	User     string
	Password string
	Name     string
	SSLMode  string
}

// DB wraps the sql.DB with logging
type DB struct {
	*sql.DB
	logger *zap.Logger
	driver string
}

// New creates a new database connection
func New(cfg Config, logger *zap.Logger) (*DB, error) {
	var dsn string
	
	switch cfg.Driver {
	case "sqlite", "sqlite3":
		dsn = cfg.Name
		if dsn == "" {
			dsn = "nexus.db"
		}
	case "postgres":
		dsn = fmt.Sprintf(
			"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
			cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Name, cfg.SSLMode,
		)
	default:
		return nil, fmt.Errorf("unsupported database driver: %s", cfg.Driver)
	}

	driverName := cfg.Driver
	if driverName == "sqlite" {
		driverName = "sqlite3"
	}

	db, err := sql.Open(driverName, dsn)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Configure connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)
	db.SetConnMaxIdleTime(1 * time.Minute)

	// Verify connection
	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	logger.Info("database connected",
		zap.String("driver", cfg.Driver),
		zap.String("database", cfg.Name),
	)

	return &DB{
		DB:     db,
		logger: logger,
		driver: cfg.Driver,
	}, nil
}

// Migrate runs database migrations
func (db *DB) Migrate() error {
	db.logger.Info("running database migrations")

	// Create stakes table
	stakesTable := `
	CREATE TABLE IF NOT EXISTS stakes (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		address TEXT NOT NULL,
		amount TEXT NOT NULL,
		shares TEXT NOT NULL,
		status TEXT NOT NULL DEFAULT active,
		delegated_to TEXT,
		unstake_init_at DATETIME,
		unstake_ready_at DATETIME,
		created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
		updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_stakes_address ON stakes(address);
	CREATE INDEX IF NOT EXISTS idx_stakes_status ON stakes(status);
	`

	// Create token_transfers table
	transfersTable := `
	CREATE TABLE IF NOT EXISTS token_transfers (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		transaction_hash TEXT NOT NULL UNIQUE,
		block_number INTEGER NOT NULL,
		from_address TEXT NOT NULL,
		to_address TEXT NOT NULL,
		amount TEXT NOT NULL,
		timestamp DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	CREATE INDEX IF NOT EXISTS idx_transfers_from ON token_transfers(from_address);
	CREATE INDEX IF NOT EXISTS idx_transfers_to ON token_transfers(to_address);
	CREATE INDEX IF NOT EXISTS idx_transfers_block ON token_transfers(block_number);
	`

	// Create staking_config table for global staking parameters
	configTable := `
	CREATE TABLE IF NOT EXISTS staking_config (
		id INTEGER PRIMARY KEY CHECK (id = 1),
		total_staked TEXT NOT NULL DEFAULT 0,
		total_shares TEXT NOT NULL DEFAULT 0,
		apy REAL NOT NULL DEFAULT 0.12,
		min_stake TEXT NOT NULL DEFAULT 1000000000000000000,
		unstaking_period_days INTEGER NOT NULL DEFAULT 7,
		rewards_per_block TEXT NOT NULL DEFAULT 100000000000000000,
		last_reward_block INTEGER NOT NULL DEFAULT 0,
		acc_rewards_per_share TEXT NOT NULL DEFAULT 0,
		updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
	);
	INSERT OR IGNORE INTO staking_config (id) VALUES (1);
	`

	// Adjust for PostgreSQL if needed
	if db.driver == "postgres" {
		stakesTable = `
		CREATE TABLE IF NOT EXISTS stakes (
			id SERIAL PRIMARY KEY,
			address VARCHAR(42) NOT NULL,
			amount VARCHAR(78) NOT NULL,
			shares VARCHAR(78) NOT NULL,
			status VARCHAR(20) NOT NULL DEFAULT active,
			delegated_to VARCHAR(42),
			unstake_init_at TIMESTAMP,
			unstake_ready_at TIMESTAMP,
			created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		CREATE INDEX IF NOT EXISTS idx_stakes_address ON stakes(address);
		CREATE INDEX IF NOT EXISTS idx_stakes_status ON stakes(status);
		`

		transfersTable = `
		CREATE TABLE IF NOT EXISTS token_transfers (
			id SERIAL PRIMARY KEY,
			transaction_hash VARCHAR(66) NOT NULL UNIQUE,
			block_number BIGINT NOT NULL,
			from_address VARCHAR(42) NOT NULL,
			to_address VARCHAR(42) NOT NULL,
			amount VARCHAR(78) NOT NULL,
			timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		CREATE INDEX IF NOT EXISTS idx_transfers_from ON token_transfers(from_address);
		CREATE INDEX IF NOT EXISTS idx_transfers_to ON token_transfers(to_address);
		CREATE INDEX IF NOT EXISTS idx_transfers_block ON token_transfers(block_number);
		`

		configTable = `
		CREATE TABLE IF NOT EXISTS staking_config (
			id INTEGER PRIMARY KEY CHECK (id = 1),
			total_staked VARCHAR(78) NOT NULL DEFAULT 0,
			total_shares VARCHAR(78) NOT NULL DEFAULT 0,
			apy REAL NOT NULL DEFAULT 0.12,
			min_stake VARCHAR(78) NOT NULL DEFAULT 1000000000000000000,
			unstaking_period_days INTEGER NOT NULL DEFAULT 7,
			rewards_per_block VARCHAR(78) NOT NULL DEFAULT 100000000000000000,
			last_reward_block BIGINT NOT NULL DEFAULT 0,
			acc_rewards_per_share VARCHAR(78) NOT NULL DEFAULT 0,
			updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
		);
		INSERT INTO staking_config (id) VALUES (1) ON CONFLICT DO NOTHING;
		`
	}

	// Execute migrations
	migrations := []string{stakesTable, transfersTable, configTable}
	for _, migration := range migrations {
		if _, err := db.Exec(migration); err != nil {
			return fmt.Errorf("migration failed: %w", err)
		}
	}

	db.logger.Info("database migrations completed")
	return nil
}

// HealthCheck verifies the database connection
func (db *DB) HealthCheck() error {
	return db.Ping()
}

// Close closes the database connection
func (db *DB) Close() error {
	db.logger.Info("closing database connection")
	return db.DB.Close()
}
