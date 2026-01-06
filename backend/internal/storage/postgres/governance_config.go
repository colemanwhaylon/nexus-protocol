// Package postgres implements repository interfaces using PostgreSQL
package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"math/big"
	"time"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresGovernanceConfigRepo implements GovernanceConfigRepository
var _ repository.GovernanceConfigRepository = (*PostgresGovernanceConfigRepo)(nil)

// PostgresGovernanceConfigRepo implements GovernanceConfigRepository using PostgreSQL
type PostgresGovernanceConfigRepo struct {
	db *sql.DB
}

// NewPostgresGovernanceConfigRepo creates a new PostgreSQL governance config repository
func NewPostgresGovernanceConfigRepo(db *sql.DB) *PostgresGovernanceConfigRepo {
	return &PostgresGovernanceConfigRepo{db: db}
}

// GetConfig retrieves a governance config by key and chain ID
func (r *PostgresGovernanceConfigRepo) GetConfig(ctx context.Context, configKey string, chainID int64) (*repository.GovernanceConfig, error) {
	query := `
		SELECT id, config_key, config_name, description, value_wei, value_number,
		       value_percent, value_string, value_type, unit_label, chain_id,
		       contract_synced, last_sync_tx, last_sync_at, is_active,
		       created_at, updated_at, updated_by
		FROM governance_config
		WHERE config_key = $1 AND chain_id = $2
	`

	c := &repository.GovernanceConfig{}
	var (
		valueWei     sql.NullString
		valueNumber  sql.NullInt64
		valuePercent sql.NullFloat64
		valueString  sql.NullString
		lastSyncTx   sql.NullString
		lastSyncAt   sql.NullTime
		updatedBy    sql.NullString
	)

	err := r.db.QueryRowContext(ctx, query, configKey, chainID).Scan(
		&c.ID,
		&c.ConfigKey,
		&c.ConfigName,
		&c.Description,
		&valueWei,
		&valueNumber,
		&valuePercent,
		&valueString,
		&c.ValueType,
		&c.UnitLabel,
		&c.ChainID,
		&c.ContractSynced,
		&lastSyncTx,
		&lastSyncAt,
		&c.IsActive,
		&c.CreatedAt,
		&c.UpdatedAt,
		&updatedBy,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrGovernanceConfigNotFound
		}
		return nil, fmt.Errorf("getting governance config %s for chain %d: %w", configKey, chainID, err)
	}

	// Convert nullable fields
	if valueWei.Valid {
		c.ValueWei, _ = new(big.Int).SetString(valueWei.String, 10)
	}
	if valueNumber.Valid {
		c.ValueNumber = &valueNumber.Int64
	}
	if valuePercent.Valid {
		c.ValuePercent = &valuePercent.Float64
	}
	if valueString.Valid {
		c.ValueString = &valueString.String
	}
	if lastSyncTx.Valid {
		c.LastSyncTx = &lastSyncTx.String
	}
	if lastSyncAt.Valid {
		c.LastSyncAt = &lastSyncAt.Time
	}
	if updatedBy.Valid {
		c.UpdatedBy = &updatedBy.String
	}

	return c, nil
}

// ListConfigs retrieves all governance configs for a chain
func (r *PostgresGovernanceConfigRepo) ListConfigs(ctx context.Context, chainID int64, activeOnly bool) ([]*repository.GovernanceConfig, error) {
	query := `
		SELECT id, config_key, config_name, description, value_wei, value_number,
		       value_percent, value_string, value_type, unit_label, chain_id,
		       contract_synced, last_sync_tx, last_sync_at, is_active,
		       created_at, updated_at, updated_by
		FROM governance_config
		WHERE chain_id = $1
	`
	if activeOnly {
		query += " AND is_active = true"
	}
	query += " ORDER BY config_key"

	rows, err := r.db.QueryContext(ctx, query, chainID)
	if err != nil {
		return nil, fmt.Errorf("listing governance configs for chain %d: %w", chainID, err)
	}
	defer rows.Close()

	var result []*repository.GovernanceConfig
	for rows.Next() {
		c := &repository.GovernanceConfig{}
		var (
			valueWei     sql.NullString
			valueNumber  sql.NullInt64
			valuePercent sql.NullFloat64
			valueString  sql.NullString
			lastSyncTx   sql.NullString
			lastSyncAt   sql.NullTime
			updatedBy    sql.NullString
		)

		err := rows.Scan(
			&c.ID,
			&c.ConfigKey,
			&c.ConfigName,
			&c.Description,
			&valueWei,
			&valueNumber,
			&valuePercent,
			&valueString,
			&c.ValueType,
			&c.UnitLabel,
			&c.ChainID,
			&c.ContractSynced,
			&lastSyncTx,
			&lastSyncAt,
			&c.IsActive,
			&c.CreatedAt,
			&c.UpdatedAt,
			&updatedBy,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning governance config row: %w", err)
		}

		// Convert nullable fields
		if valueWei.Valid {
			c.ValueWei, _ = new(big.Int).SetString(valueWei.String, 10)
		}
		if valueNumber.Valid {
			c.ValueNumber = &valueNumber.Int64
		}
		if valuePercent.Valid {
			c.ValuePercent = &valuePercent.Float64
		}
		if valueString.Valid {
			c.ValueString = &valueString.String
		}
		if lastSyncTx.Valid {
			c.LastSyncTx = &lastSyncTx.String
		}
		if lastSyncAt.Valid {
			c.LastSyncAt = &lastSyncAt.Time
		}
		if updatedBy.Valid {
			c.UpdatedBy = &updatedBy.String
		}

		result = append(result, c)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating governance config rows: %w", err)
	}

	return result, nil
}

// UpdateConfig updates a governance config
func (r *PostgresGovernanceConfigRepo) UpdateConfig(ctx context.Context, configKey string, chainID int64, update *repository.GovernanceConfigUpdate) error {
	// First check if config exists
	exists, err := r.configExists(ctx, configKey, chainID)
	if err != nil {
		return err
	}
	if !exists {
		return repository.ErrGovernanceConfigNotFound
	}

	// Build dynamic update query
	query := "UPDATE governance_config SET updated_by = $3"
	args := []interface{}{configKey, chainID, update.UpdatedBy}
	argNum := 4

	if update.ValueWei != nil {
		query += fmt.Sprintf(", value_wei = $%d", argNum)
		args = append(args, update.ValueWei.String())
		argNum++
	}
	if update.ValueNumber != nil {
		query += fmt.Sprintf(", value_number = $%d", argNum)
		args = append(args, *update.ValueNumber)
		argNum++
	}
	if update.ValuePercent != nil {
		query += fmt.Sprintf(", value_percent = $%d", argNum)
		args = append(args, *update.ValuePercent)
		argNum++
	}
	if update.ValueString != nil {
		query += fmt.Sprintf(", value_string = $%d", argNum)
		args = append(args, *update.ValueString)
		argNum++
	}
	if update.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argNum)
		args = append(args, *update.IsActive)
	}

	query += " WHERE config_key = $1 AND chain_id = $2"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating governance config %s for chain %d: %w", configKey, chainID, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrGovernanceConfigNotFound
	}

	return nil
}

// MarkSynced marks a governance config as synced with the smart contract
func (r *PostgresGovernanceConfigRepo) MarkSynced(ctx context.Context, configKey string, chainID int64, txHash string) error {
	query := `
		UPDATE governance_config
		SET contract_synced = true,
		    last_sync_tx = $3,
		    last_sync_at = $4
		WHERE config_key = $1 AND chain_id = $2
	`

	result, err := r.db.ExecContext(ctx, query, configKey, chainID, txHash, time.Now())
	if err != nil {
		return fmt.Errorf("marking governance config %s synced: %w", configKey, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrGovernanceConfigNotFound
	}

	return nil
}

// GetConfigHistory retrieves config change history
func (r *PostgresGovernanceConfigRepo) GetConfigHistory(ctx context.Context, configKey string, chainID int64, limit int) ([]*repository.GovernanceConfigHistoryEntry, error) {
	query := `
		SELECT h.id, h.governance_config_id, h.old_value_wei, h.old_value_number,
		       h.old_value_percent, h.old_value_string, h.new_value_wei, h.new_value_number,
		       h.new_value_percent, h.new_value_string, h.was_synced, h.sync_tx,
		       h.changed_by, h.changed_at, h.change_reason
		FROM governance_config_history h
		JOIN governance_config c ON h.governance_config_id = c.id
		WHERE c.config_key = $1 AND c.chain_id = $2
		ORDER BY h.changed_at DESC
		LIMIT $3
	`

	rows, err := r.db.QueryContext(ctx, query, configKey, chainID, limit)
	if err != nil {
		return nil, fmt.Errorf("getting governance config history: %w", err)
	}
	defer rows.Close()

	var result []*repository.GovernanceConfigHistoryEntry
	for rows.Next() {
		h := &repository.GovernanceConfigHistoryEntry{}
		var (
			oldValueWei     sql.NullString
			oldValueNumber  sql.NullInt64
			oldValuePercent sql.NullFloat64
			oldValueString  sql.NullString
			newValueWei     sql.NullString
			newValueNumber  sql.NullInt64
			newValuePercent sql.NullFloat64
			newValueString  sql.NullString
			wasSynced       sql.NullBool
			syncTx          sql.NullString
			changeReason    sql.NullString
		)

		err := rows.Scan(
			&h.ID,
			&h.GovernanceConfigID,
			&oldValueWei,
			&oldValueNumber,
			&oldValuePercent,
			&oldValueString,
			&newValueWei,
			&newValueNumber,
			&newValuePercent,
			&newValueString,
			&wasSynced,
			&syncTx,
			&h.ChangedBy,
			&h.ChangedAt,
			&changeReason,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning governance config history row: %w", err)
		}

		// Convert nullable fields
		if oldValueWei.Valid {
			h.OldValueWei, _ = new(big.Int).SetString(oldValueWei.String, 10)
		}
		if oldValueNumber.Valid {
			h.OldValueNumber = &oldValueNumber.Int64
		}
		if oldValuePercent.Valid {
			h.OldValuePercent = &oldValuePercent.Float64
		}
		if oldValueString.Valid {
			h.OldValueString = &oldValueString.String
		}
		if newValueWei.Valid {
			h.NewValueWei, _ = new(big.Int).SetString(newValueWei.String, 10)
		}
		if newValueNumber.Valid {
			h.NewValueNumber = &newValueNumber.Int64
		}
		if newValuePercent.Valid {
			h.NewValuePercent = &newValuePercent.Float64
		}
		if newValueString.Valid {
			h.NewValueString = &newValueString.String
		}
		if wasSynced.Valid {
			h.WasSynced = &wasSynced.Bool
		}
		if syncTx.Valid {
			h.SyncTx = &syncTx.String
		}
		if changeReason.Valid {
			h.ChangeReason = &changeReason.String
		}

		result = append(result, h)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating governance config history rows: %w", err)
	}

	return result, nil
}

// configExists checks if a governance config exists
func (r *PostgresGovernanceConfigRepo) configExists(ctx context.Context, configKey string, chainID int64) (bool, error) {
	query := "SELECT EXISTS(SELECT 1 FROM governance_config WHERE config_key = $1 AND chain_id = $2)"
	var exists bool
	err := r.db.QueryRowContext(ctx, query, configKey, chainID).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking governance config exists: %w", err)
	}
	return exists, nil
}
