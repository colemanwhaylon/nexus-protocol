// Package postgres implements repository interfaces using PostgreSQL
package postgres

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"math/big"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresAppConfigRepo implements AppConfigRepository
var _ repository.AppConfigRepository = (*PostgresAppConfigRepo)(nil)

// PostgresAppConfigRepo implements AppConfigRepository using PostgreSQL
type PostgresAppConfigRepo struct {
	db *sql.DB
}

// NewPostgresAppConfigRepo creates a new PostgreSQL app config repository
func NewPostgresAppConfigRepo(db *sql.DB) *PostgresAppConfigRepo {
	return &PostgresAppConfigRepo{db: db}
}

// scanConfig is a helper to scan a config row into an AppConfig struct
func (r *PostgresAppConfigRepo) scanConfig(row interface{ Scan(...interface{}) error }) (*repository.AppConfig, error) {
	c := &repository.AppConfig{}
	var (
		valueString  sql.NullString
		valueNumber  sql.NullInt64
		valueWei     sql.NullString
		valueBoolean sql.NullBool
		updatedBy    sql.NullString
	)

	err := row.Scan(
		&c.ID,
		&c.Namespace,
		&c.ConfigKey,
		&c.ValueType,
		&valueString,
		&valueNumber,
		&valueWei,
		&valueBoolean,
		&c.Description,
		&c.IsSecret,
		&c.IsActive,
		&c.ChainID,
		&updatedBy,
		&c.CreatedAt,
		&c.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}

	// Convert nullable fields
	if valueString.Valid {
		c.ValueString = &valueString.String
	}
	if valueNumber.Valid {
		c.ValueNumber = &valueNumber.Int64
	}
	if valueWei.Valid {
		c.ValueWei, _ = new(big.Int).SetString(valueWei.String, 10)
	}
	if valueBoolean.Valid {
		c.ValueBoolean = &valueBoolean.Bool
	}
	if updatedBy.Valid {
		c.UpdatedBy = &updatedBy.String
	}

	return c, nil
}

const configSelectFields = `
	id, namespace, config_key, value_type, value_string, value_number,
	value_wei, value_boolean, description, is_secret, is_active,
	chain_id, updated_by, created_at, updated_at
`

// Get retrieves a single config by namespace, key, and chain ID
func (r *PostgresAppConfigRepo) Get(ctx context.Context, namespace, key string, chainID int64) (*repository.AppConfig, error) {
	query := `SELECT ` + configSelectFields + `
		FROM app_config
		WHERE namespace = $1 AND config_key = $2 AND chain_id = $3 AND is_active = true`

	row := r.db.QueryRowContext(ctx, query, namespace, key, chainID)
	config, err := r.scanConfig(row)
	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrAppConfigNotFound
		}
		return nil, fmt.Errorf("getting app config %s.%s for chain %d: %w", namespace, key, chainID, err)
	}

	return config, nil
}

// GetWithFallback tries chain-specific first, then falls back to chain_id=0 (global)
func (r *PostgresAppConfigRepo) GetWithFallback(ctx context.Context, namespace, key string, chainID int64) (*repository.AppConfig, error) {
	// Try chain-specific first
	config, err := r.Get(ctx, namespace, key, chainID)
	if err == nil {
		return config, nil
	}
	if !errors.Is(err, repository.ErrAppConfigNotFound) {
		return nil, err
	}

	// Fall back to global (chain_id = 0)
	config, err = r.Get(ctx, namespace, key, 0)
	if err != nil {
		if errors.Is(err, repository.ErrAppConfigNotFound) {
			return nil, fmt.Errorf("config %s.%s not found for chain %d or globally: %w", namespace, key, chainID, repository.ErrAppConfigNotFound)
		}
		return nil, err
	}

	return config, nil
}

// ListByNamespace retrieves all configs for a namespace and chain
func (r *PostgresAppConfigRepo) ListByNamespace(ctx context.Context, namespace string, chainID int64) ([]*repository.AppConfig, error) {
	query := `SELECT ` + configSelectFields + `
		FROM app_config
		WHERE namespace = $1 AND (chain_id = $2 OR chain_id = 0) AND is_active = true
		ORDER BY config_key`

	rows, err := r.db.QueryContext(ctx, query, namespace, chainID)
	if err != nil {
		return nil, fmt.Errorf("listing app configs for namespace %s: %w", namespace, err)
	}
	defer rows.Close()

	var result []*repository.AppConfig
	for rows.Next() {
		config, err := r.scanConfig(rows)
		if err != nil {
			return nil, fmt.Errorf("scanning app config row: %w", err)
		}
		result = append(result, config)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating app config rows: %w", err)
	}

	return result, nil
}

// ListAll retrieves all configs (for admin)
func (r *PostgresAppConfigRepo) ListAll(ctx context.Context) ([]*repository.AppConfig, error) {
	query := `SELECT ` + configSelectFields + `
		FROM app_config
		ORDER BY namespace, config_key, chain_id`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("listing all app configs: %w", err)
	}
	defer rows.Close()

	var result []*repository.AppConfig
	for rows.Next() {
		config, err := r.scanConfig(rows)
		if err != nil {
			return nil, fmt.Errorf("scanning app config row: %w", err)
		}
		result = append(result, config)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating app config rows: %w", err)
	}

	return result, nil
}

// Typed getters with fallback

// GetString returns the string value for a config
func (r *PostgresAppConfigRepo) GetString(ctx context.Context, namespace, key string, chainID int64) (string, error) {
	config, err := r.GetWithFallback(ctx, namespace, key, chainID)
	if err != nil {
		return "", err
	}
	return config.GetStringValue(), nil
}

// GetNumber returns the number value for a config
func (r *PostgresAppConfigRepo) GetNumber(ctx context.Context, namespace, key string, chainID int64) (int64, error) {
	config, err := r.GetWithFallback(ctx, namespace, key, chainID)
	if err != nil {
		return 0, err
	}
	return config.GetNumberValue(), nil
}

// GetWei returns the wei value for a config
func (r *PostgresAppConfigRepo) GetWei(ctx context.Context, namespace, key string, chainID int64) (*big.Int, error) {
	config, err := r.GetWithFallback(ctx, namespace, key, chainID)
	if err != nil {
		return nil, err
	}
	return config.GetWeiValue(), nil
}

// GetBool returns the boolean value for a config
func (r *PostgresAppConfigRepo) GetBool(ctx context.Context, namespace, key string, chainID int64) (bool, error) {
	config, err := r.GetWithFallback(ctx, namespace, key, chainID)
	if err != nil {
		return false, err
	}
	return config.GetBoolValue(), nil
}

// GetJSON parses the string value as JSON into dest
func (r *PostgresAppConfigRepo) GetJSON(ctx context.Context, namespace, key string, chainID int64, dest interface{}) error {
	config, err := r.GetWithFallback(ctx, namespace, key, chainID)
	if err != nil {
		return err
	}
	if config.ValueString == nil {
		return nil
	}
	return json.Unmarshal([]byte(*config.ValueString), dest)
}

// Update updates an existing config
func (r *PostgresAppConfigRepo) Update(ctx context.Context, namespace, key string, chainID int64, update *repository.AppConfigUpdate) error {
	// First check if config exists
	exists, err := r.configExists(ctx, namespace, key, chainID)
	if err != nil {
		return err
	}
	if !exists {
		return repository.ErrAppConfigNotFound
	}

	// Build dynamic update query
	query := "UPDATE app_config SET updated_by = $4, updated_at = NOW()"
	args := []interface{}{namespace, key, chainID, update.UpdatedBy}
	argNum := 5

	if update.ValueString != nil {
		query += fmt.Sprintf(", value_string = $%d", argNum)
		args = append(args, *update.ValueString)
		argNum++
	}
	if update.ValueNumber != nil {
		query += fmt.Sprintf(", value_number = $%d", argNum)
		args = append(args, *update.ValueNumber)
		argNum++
	}
	if update.ValueWei != nil {
		query += fmt.Sprintf(", value_wei = $%d", argNum)
		args = append(args, update.ValueWei.String())
		argNum++
	}
	if update.ValueBoolean != nil {
		query += fmt.Sprintf(", value_boolean = $%d", argNum)
		args = append(args, *update.ValueBoolean)
		argNum++
	}
	if update.Description != nil {
		query += fmt.Sprintf(", description = $%d", argNum)
		args = append(args, *update.Description)
		argNum++
	}
	if update.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argNum)
		args = append(args, *update.IsActive)
	}

	query += " WHERE namespace = $1 AND config_key = $2 AND chain_id = $3"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating app config %s.%s for chain %d: %w", namespace, key, chainID, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrAppConfigNotFound
	}

	return nil
}

// Create creates a new config
func (r *PostgresAppConfigRepo) Create(ctx context.Context, config *repository.AppConfigCreate) error {
	query := `
		INSERT INTO app_config (
			namespace, config_key, value_type, value_string, value_number,
			value_wei, value_boolean, description, is_secret, chain_id, updated_by
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
	`

	var valueWei *string
	if config.ValueWei != nil {
		s := config.ValueWei.String()
		valueWei = &s
	}

	_, err := r.db.ExecContext(ctx, query,
		config.Namespace,
		config.ConfigKey,
		config.ValueType,
		config.ValueString,
		config.ValueNumber,
		valueWei,
		config.ValueBoolean,
		config.Description,
		config.IsSecret,
		config.ChainID,
		config.UpdatedBy,
	)
	if err != nil {
		return fmt.Errorf("creating app config %s.%s: %w", config.Namespace, config.ConfigKey, err)
	}

	return nil
}

// Delete soft-deletes a config by setting is_active=false
func (r *PostgresAppConfigRepo) Delete(ctx context.Context, namespace, key string, chainID int64, deletedBy string) error {
	query := `
		UPDATE app_config
		SET is_active = false, updated_by = $4, updated_at = NOW()
		WHERE namespace = $1 AND config_key = $2 AND chain_id = $3
	`

	result, err := r.db.ExecContext(ctx, query, namespace, key, chainID, deletedBy)
	if err != nil {
		return fmt.Errorf("deleting app config %s.%s: %w", namespace, key, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrAppConfigNotFound
	}

	return nil
}

// GetHistory retrieves change history for a config
func (r *PostgresAppConfigRepo) GetHistory(ctx context.Context, namespace, key string, chainID int64, limit int) ([]*repository.AppConfigHistoryEntry, error) {
	query := `
		SELECT h.id, h.app_config_id,
		       h.old_value_string, h.old_value_number, h.old_value_wei, h.old_value_boolean,
		       h.new_value_string, h.new_value_number, h.new_value_wei, h.new_value_boolean,
		       h.changed_by, h.changed_at, h.change_reason
		FROM app_config_history h
		JOIN app_config c ON h.app_config_id = c.id
		WHERE c.namespace = $1 AND c.config_key = $2 AND c.chain_id = $3
		ORDER BY h.changed_at DESC
		LIMIT $4
	`

	rows, err := r.db.QueryContext(ctx, query, namespace, key, chainID, limit)
	if err != nil {
		return nil, fmt.Errorf("getting app config history: %w", err)
	}
	defer rows.Close()

	var result []*repository.AppConfigHistoryEntry
	for rows.Next() {
		h := &repository.AppConfigHistoryEntry{}
		var (
			oldValueString  sql.NullString
			oldValueNumber  sql.NullInt64
			oldValueWei     sql.NullString
			oldValueBoolean sql.NullBool
			newValueString  sql.NullString
			newValueNumber  sql.NullInt64
			newValueWei     sql.NullString
			newValueBoolean sql.NullBool
			changeReason    sql.NullString
		)

		err := rows.Scan(
			&h.ID,
			&h.AppConfigID,
			&oldValueString,
			&oldValueNumber,
			&oldValueWei,
			&oldValueBoolean,
			&newValueString,
			&newValueNumber,
			&newValueWei,
			&newValueBoolean,
			&h.ChangedBy,
			&h.ChangedAt,
			&changeReason,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning app config history row: %w", err)
		}

		// Convert nullable fields
		if oldValueString.Valid {
			h.OldValueString = &oldValueString.String
		}
		if oldValueNumber.Valid {
			h.OldValueNumber = &oldValueNumber.Int64
		}
		if oldValueWei.Valid {
			h.OldValueWei, _ = new(big.Int).SetString(oldValueWei.String, 10)
		}
		if oldValueBoolean.Valid {
			h.OldValueBoolean = &oldValueBoolean.Bool
		}
		if newValueString.Valid {
			h.NewValueString = &newValueString.String
		}
		if newValueNumber.Valid {
			h.NewValueNumber = &newValueNumber.Int64
		}
		if newValueWei.Valid {
			h.NewValueWei, _ = new(big.Int).SetString(newValueWei.String, 10)
		}
		if newValueBoolean.Valid {
			h.NewValueBoolean = &newValueBoolean.Bool
		}
		if changeReason.Valid {
			h.ChangeReason = &changeReason.String
		}

		result = append(result, h)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating app config history rows: %w", err)
	}

	return result, nil
}

// configExists checks if a config exists
func (r *PostgresAppConfigRepo) configExists(ctx context.Context, namespace, key string, chainID int64) (bool, error) {
	query := "SELECT EXISTS(SELECT 1 FROM app_config WHERE namespace = $1 AND config_key = $2 AND chain_id = $3)"
	var exists bool
	err := r.db.QueryRowContext(ctx, query, namespace, key, chainID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking app config exists: %w", err)
	}
	return exists, nil
}
