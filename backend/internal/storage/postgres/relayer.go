// Package postgres implements repository interfaces using PostgreSQL
package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"time"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresRelayerRepo implements RelayerRepository
var _ repository.RelayerRepository = (*PostgresRelayerRepo)(nil)

// PostgresRelayerRepo implements RelayerRepository using PostgreSQL
type PostgresRelayerRepo struct {
	db *sql.DB
}

// NewPostgresRelayerRepo creates a new PostgreSQL relayer repository
func NewPostgresRelayerRepo(db *sql.DB) *PostgresRelayerRepo {
	return &PostgresRelayerRepo{db: db}
}

// CreateMetaTx creates a new meta-transaction record
func (r *PostgresRelayerRepo) CreateMetaTx(ctx context.Context, tx *repository.MetaTransaction) error {
	query := `
		INSERT INTO meta_transactions (
			from_address, to_address, function_name, calldata, value,
			gas_limit, nonce, deadline, signature, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(ctx, query,
		tx.FromAddress,
		tx.ToAddress,
		tx.FunctionName,
		tx.Calldata,
		tx.Value,
		tx.GasLimit,
		tx.Nonce,
		tx.Deadline,
		tx.Signature,
		tx.Status,
	).Scan(&tx.ID, &tx.CreatedAt, &tx.UpdatedAt)

	if err != nil {
		return fmt.Errorf("creating meta-transaction: %w", err)
	}

	return nil
}

// GetMetaTx retrieves a meta-transaction by ID
func (r *PostgresRelayerRepo) GetMetaTx(ctx context.Context, id string) (*repository.MetaTransaction, error) {
	query := `
		SELECT id, from_address, to_address, function_name, calldata, value,
		       gas_limit, nonce, deadline, signature, status, tx_hash,
		       gas_used, gas_price, relay_cost_eth, error_message, retry_count,
		       created_at, updated_at, submitted_at, confirmed_at
		FROM meta_transactions
		WHERE id = $1
	`

	tx := &repository.MetaTransaction{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&tx.ID,
		&tx.FromAddress,
		&tx.ToAddress,
		&tx.FunctionName,
		&tx.Calldata,
		&tx.Value,
		&tx.GasLimit,
		&tx.Nonce,
		&tx.Deadline,
		&tx.Signature,
		&tx.Status,
		&tx.TxHash,
		&tx.GasUsed,
		&tx.GasPrice,
		&tx.RelayCostETH,
		&tx.ErrorMessage,
		&tx.RetryCount,
		&tx.CreatedAt,
		&tx.UpdatedAt,
		&tx.SubmittedAt,
		&tx.ConfirmedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrMetaTxNotFound
		}
		return nil, fmt.Errorf("getting meta-transaction %s: %w", id, err)
	}

	return tx, nil
}

// GetMetaTxByHash retrieves a meta-transaction by blockchain transaction hash
func (r *PostgresRelayerRepo) GetMetaTxByHash(ctx context.Context, txHash string) (*repository.MetaTransaction, error) {
	query := `
		SELECT id, from_address, to_address, function_name, calldata, value,
		       gas_limit, nonce, deadline, signature, status, tx_hash,
		       gas_used, gas_price, relay_cost_eth, error_message, retry_count,
		       created_at, updated_at, submitted_at, confirmed_at
		FROM meta_transactions
		WHERE tx_hash = $1
	`

	tx := &repository.MetaTransaction{}
	err := r.db.QueryRowContext(ctx, query, txHash).Scan(
		&tx.ID,
		&tx.FromAddress,
		&tx.ToAddress,
		&tx.FunctionName,
		&tx.Calldata,
		&tx.Value,
		&tx.GasLimit,
		&tx.Nonce,
		&tx.Deadline,
		&tx.Signature,
		&tx.Status,
		&tx.TxHash,
		&tx.GasUsed,
		&tx.GasPrice,
		&tx.RelayCostETH,
		&tx.ErrorMessage,
		&tx.RetryCount,
		&tx.CreatedAt,
		&tx.UpdatedAt,
		&tx.SubmittedAt,
		&tx.ConfirmedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrMetaTxNotFound
		}
		return nil, fmt.Errorf("getting meta-transaction by hash %s: %w", txHash, err)
	}

	return tx, nil
}

// UpdateMetaTxStatus updates the status of a meta-transaction
func (r *PostgresRelayerRepo) UpdateMetaTxStatus(ctx context.Context, id string, update *repository.MetaTxStatusUpdate) error {
	// Build dynamic update query
	query := "UPDATE meta_transactions SET status = $2, updated_at = NOW()"
	args := []interface{}{id, update.Status}
	argNum := 3

	if update.TxHash != nil {
		query += fmt.Sprintf(", tx_hash = $%d", argNum)
		args = append(args, *update.TxHash)
		argNum++
	}
	if update.GasUsed != nil {
		query += fmt.Sprintf(", gas_used = $%d", argNum)
		args = append(args, *update.GasUsed)
		argNum++
	}
	if update.GasPrice != nil {
		query += fmt.Sprintf(", gas_price = $%d", argNum)
		args = append(args, *update.GasPrice)
		argNum++
	}
	if update.RelayCostETH != nil {
		query += fmt.Sprintf(", relay_cost_eth = $%d", argNum)
		args = append(args, *update.RelayCostETH)
		argNum++
	}
	if update.ErrorMessage != nil {
		query += fmt.Sprintf(", error_message = $%d", argNum)
		args = append(args, *update.ErrorMessage)
		argNum++
	}

	// Set timestamp based on status
	switch update.Status {
	case repository.MetaTxStatusSubmitted:
		query += ", submitted_at = NOW()"
	case repository.MetaTxStatusConfirmed:
		query += ", confirmed_at = NOW()"
	}

	query += " WHERE id = $1"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating meta-transaction status %s: %w", id, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrMetaTxNotFound
	}

	return nil
}

// ListMetaTx lists meta-transactions with filtering and pagination
func (r *PostgresRelayerRepo) ListMetaTx(ctx context.Context, filter repository.MetaTxFilter, page repository.Pagination) ([]*repository.MetaTransaction, int64, error) {
	// Build WHERE clause
	whereClause := "WHERE 1=1"
	args := []interface{}{}
	argNum := 1

	if filter.FromAddress != "" {
		whereClause += fmt.Sprintf(" AND from_address = $%d", argNum)
		args = append(args, filter.FromAddress)
		argNum++
	}
	if filter.ToAddress != "" {
		whereClause += fmt.Sprintf(" AND to_address = $%d", argNum)
		args = append(args, filter.ToAddress)
		argNum++
	}
	if filter.FunctionName != "" {
		whereClause += fmt.Sprintf(" AND function_name = $%d", argNum)
		args = append(args, filter.FunctionName)
		argNum++
	}
	if filter.Status != "" {
		whereClause += fmt.Sprintf(" AND status = $%d", argNum)
		args = append(args, filter.Status)
		argNum++
	}

	// Count total matching records
	countQuery := fmt.Sprintf("SELECT COUNT(*) FROM meta_transactions %s", whereClause)
	var total int64
	err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, fmt.Errorf("counting meta-transactions: %w", err)
	}

	// Get paginated results
	offset := (page.Page - 1) * page.PageSize
	query := fmt.Sprintf(`
		SELECT id, from_address, to_address, function_name, calldata, value,
		       gas_limit, nonce, deadline, signature, status, tx_hash,
		       gas_used, gas_price, relay_cost_eth, error_message, retry_count,
		       created_at, updated_at, submitted_at, confirmed_at
		FROM meta_transactions
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	args = append(args, page.PageSize, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("listing meta-transactions: %w", err)
	}
	defer rows.Close()

	var result []*repository.MetaTransaction
	for rows.Next() {
		tx := &repository.MetaTransaction{}
		err := rows.Scan(
			&tx.ID,
			&tx.FromAddress,
			&tx.ToAddress,
			&tx.FunctionName,
			&tx.Calldata,
			&tx.Value,
			&tx.GasLimit,
			&tx.Nonce,
			&tx.Deadline,
			&tx.Signature,
			&tx.Status,
			&tx.TxHash,
			&tx.GasUsed,
			&tx.GasPrice,
			&tx.RelayCostETH,
			&tx.ErrorMessage,
			&tx.RetryCount,
			&tx.CreatedAt,
			&tx.UpdatedAt,
			&tx.SubmittedAt,
			&tx.ConfirmedAt,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scanning meta-transaction row: %w", err)
		}
		result = append(result, tx)
	}

	if err := rows.Err(); err != nil {
		return nil, 0, fmt.Errorf("iterating meta-transaction rows: %w", err)
	}

	return result, total, nil
}

// GetNextNonce retrieves the next nonce for an address
func (r *PostgresRelayerRepo) GetNextNonce(ctx context.Context, fromAddress string) (uint64, error) {
	query := `
		SELECT COALESCE(MAX(nonce), 0) + 1
		FROM meta_transactions
		WHERE from_address = $1
		  AND status NOT IN ('failed', 'expired', 'cancelled')
	`

	var nextNonce uint64
	err := r.db.QueryRowContext(ctx, query, fromAddress).Scan(&nextNonce)
	if err != nil {
		return 0, fmt.Errorf("getting next nonce for %s: %w", fromAddress, err)
	}

	return nextNonce, nil
}

// GetPendingMetaTxs retrieves pending meta-transactions ready for submission
func (r *PostgresRelayerRepo) GetPendingMetaTxs(ctx context.Context, limit int) ([]*repository.MetaTransaction, error) {
	query := `
		SELECT id, from_address, to_address, function_name, calldata, value,
		       gas_limit, nonce, deadline, signature, status, tx_hash,
		       gas_used, gas_price, relay_cost_eth, error_message, retry_count,
		       created_at, updated_at, submitted_at, confirmed_at
		FROM meta_transactions
		WHERE status = 'pending'
		  AND deadline > NOW()
		ORDER BY created_at ASC
		LIMIT $1
	`

	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("getting pending meta-transactions: %w", err)
	}
	defer rows.Close()

	return r.scanMetaTxRows(rows)
}

// GetExpiredMetaTxs retrieves expired meta-transactions for cleanup
func (r *PostgresRelayerRepo) GetExpiredMetaTxs(ctx context.Context, limit int) ([]*repository.MetaTransaction, error) {
	query := `
		SELECT id, from_address, to_address, function_name, calldata, value,
		       gas_limit, nonce, deadline, signature, status, tx_hash,
		       gas_used, gas_price, relay_cost_eth, error_message, retry_count,
		       created_at, updated_at, submitted_at, confirmed_at
		FROM meta_transactions
		WHERE status = 'pending'
		  AND deadline <= NOW()
		ORDER BY deadline ASC
		LIMIT $1
	`

	rows, err := r.db.QueryContext(ctx, query, limit)
	if err != nil {
		return nil, fmt.Errorf("getting expired meta-transactions: %w", err)
	}
	defer rows.Close()

	return r.scanMetaTxRows(rows)
}

// scanMetaTxRows is a helper to scan multiple meta-transaction rows
func (r *PostgresRelayerRepo) scanMetaTxRows(rows *sql.Rows) ([]*repository.MetaTransaction, error) {
	var result []*repository.MetaTransaction
	for rows.Next() {
		tx := &repository.MetaTransaction{}
		err := rows.Scan(
			&tx.ID,
			&tx.FromAddress,
			&tx.ToAddress,
			&tx.FunctionName,
			&tx.Calldata,
			&tx.Value,
			&tx.GasLimit,
			&tx.Nonce,
			&tx.Deadline,
			&tx.Signature,
			&tx.Status,
			&tx.TxHash,
			&tx.GasUsed,
			&tx.GasPrice,
			&tx.RelayCostETH,
			&tx.ErrorMessage,
			&tx.RetryCount,
			&tx.CreatedAt,
			&tx.UpdatedAt,
			&tx.SubmittedAt,
			&tx.ConfirmedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning meta-transaction row: %w", err)
		}
		result = append(result, tx)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating meta-transaction rows: %w", err)
	}

	return result, nil
}

// IncrementRetryCount increments the retry count for a meta-transaction
func (r *PostgresRelayerRepo) IncrementRetryCount(ctx context.Context, id string) error {
	query := `
		UPDATE meta_transactions
		SET retry_count = retry_count + 1, updated_at = NOW()
		WHERE id = $1
	`

	result, err := r.db.ExecContext(ctx, query, id)
	if err != nil {
		return fmt.Errorf("incrementing retry count for %s: %w", id, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrMetaTxNotFound
	}

	return nil
}

// MarkExpired marks expired pending transactions
func (r *PostgresRelayerRepo) MarkExpired(ctx context.Context) (int64, error) {
	query := `
		UPDATE meta_transactions
		SET status = 'expired', updated_at = NOW()
		WHERE status = 'pending'
		  AND deadline <= NOW()
	`

	result, err := r.db.ExecContext(ctx, query)
	if err != nil {
		return 0, fmt.Errorf("marking expired meta-transactions: %w", err)
	}

	rows, _ := result.RowsAffected()
	return rows, nil
}

// GetStats returns statistics about meta-transactions
func (r *PostgresRelayerRepo) GetStats(ctx context.Context, since time.Time) (*MetaTxStats, error) {
	query := `
		SELECT
			COUNT(*) FILTER (WHERE status = 'pending') as pending_count,
			COUNT(*) FILTER (WHERE status = 'submitted') as submitted_count,
			COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_count,
			COUNT(*) FILTER (WHERE status = 'failed') as failed_count,
			COUNT(*) FILTER (WHERE status = 'expired') as expired_count,
			COALESCE(SUM(gas_used) FILTER (WHERE status = 'confirmed'), 0) as total_gas_used,
			COALESCE(SUM(CAST(relay_cost_eth AS NUMERIC)) FILTER (WHERE status = 'confirmed'), 0) as total_relay_cost
		FROM meta_transactions
		WHERE created_at >= $1
	`

	stats := &MetaTxStats{}
	var totalRelayCost float64
	err := r.db.QueryRowContext(ctx, query, since).Scan(
		&stats.PendingCount,
		&stats.SubmittedCount,
		&stats.ConfirmedCount,
		&stats.FailedCount,
		&stats.ExpiredCount,
		&stats.TotalGasUsed,
		&totalRelayCost,
	)
	if err != nil {
		return nil, fmt.Errorf("getting meta-transaction stats: %w", err)
	}
	stats.TotalRelayCostETH = fmt.Sprintf("%.18f", totalRelayCost)

	return stats, nil
}

// MetaTxStats holds meta-transaction statistics
type MetaTxStats struct {
	PendingCount      int64  `json:"pending_count"`
	SubmittedCount    int64  `json:"submitted_count"`
	ConfirmedCount    int64  `json:"confirmed_count"`
	FailedCount       int64  `json:"failed_count"`
	ExpiredCount      int64  `json:"expired_count"`
	TotalGasUsed      uint64 `json:"total_gas_used"`
	TotalRelayCostETH string `json:"total_relay_cost_eth"`
}
