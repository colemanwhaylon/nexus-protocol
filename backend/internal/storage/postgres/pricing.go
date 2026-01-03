// Package postgres implements repository interfaces using PostgreSQL
package postgres

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresPricingRepo implements PricingRepository
var _ repository.PricingRepository = (*PostgresPricingRepo)(nil)

// PostgresPricingRepo implements PricingRepository using PostgreSQL
type PostgresPricingRepo struct {
	db *sql.DB
}

// NewPostgresPricingRepo creates a new PostgreSQL pricing repository
func NewPostgresPricingRepo(db *sql.DB) *PostgresPricingRepo {
	return &PostgresPricingRepo{db: db}
}

// GetPricing retrieves pricing for a service by code
func (r *PostgresPricingRepo) GetPricing(ctx context.Context, serviceCode string) (*repository.Pricing, error) {
	query := `
		SELECT id, service_code, service_name, description, cost_usd, cost_provider,
		       price_usd, price_eth, price_nexus, markup_percent, is_active,
		       created_at, updated_at, updated_by
		FROM pricing
		WHERE service_code = $1
	`

	p := &repository.Pricing{}
	var updatedBy sql.NullString
	err := r.db.QueryRowContext(ctx, query, serviceCode).Scan(
		&p.ID,
		&p.ServiceCode,
		&p.ServiceName,
		&p.Description,
		&p.CostUSD,
		&p.CostProvider,
		&p.PriceUSD,
		&p.PriceETH,
		&p.PriceNEXUS,
		&p.MarkupPercent,
		&p.IsActive,
		&p.CreatedAt,
		&p.UpdatedAt,
		&updatedBy,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrPricingNotFound
		}
		return nil, fmt.Errorf("getting pricing for %s: %w", serviceCode, err)
	}

	if updatedBy.Valid {
		p.UpdatedBy = updatedBy.String
	}

	return p, nil
}

// ListPricing retrieves all pricing entries
func (r *PostgresPricingRepo) ListPricing(ctx context.Context, activeOnly bool) ([]*repository.Pricing, error) {
	query := `
		SELECT id, service_code, service_name, description, cost_usd, cost_provider,
		       price_usd, price_eth, price_nexus, markup_percent, is_active,
		       created_at, updated_at, updated_by
		FROM pricing
	`
	if activeOnly {
		query += " WHERE is_active = true"
	}
	query += " ORDER BY service_code"

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("listing pricing: %w", err)
	}
	defer rows.Close()

	var result []*repository.Pricing
	for rows.Next() {
		p := &repository.Pricing{}
		var updatedBy sql.NullString
		err := rows.Scan(
			&p.ID,
			&p.ServiceCode,
			&p.ServiceName,
			&p.Description,
			&p.CostUSD,
			&p.CostProvider,
			&p.PriceUSD,
			&p.PriceETH,
			&p.PriceNEXUS,
			&p.MarkupPercent,
			&p.IsActive,
			&p.CreatedAt,
			&p.UpdatedAt,
			&updatedBy,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning pricing row: %w", err)
		}
		if updatedBy.Valid {
			p.UpdatedBy = updatedBy.String
		}
		result = append(result, p)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating pricing rows: %w", err)
	}

	return result, nil
}

// UpdatePricing updates pricing for a service
func (r *PostgresPricingRepo) UpdatePricing(ctx context.Context, serviceCode string, update *repository.PricingUpdate) error {
	// First check if pricing exists
	exists, err := r.pricingExists(ctx, serviceCode)
	if err != nil {
		return err
	}
	if !exists {
		return repository.ErrPricingNotFound
	}

	// Build dynamic update query
	query := "UPDATE pricing SET updated_by = $2"
	args := []interface{}{serviceCode, update.UpdatedBy}
	argNum := 3

	if update.PriceUSD != nil {
		query += fmt.Sprintf(", price_usd = $%d", argNum)
		args = append(args, *update.PriceUSD)
		argNum++
	}
	if update.PriceETH != nil {
		query += fmt.Sprintf(", price_eth = $%d", argNum)
		args = append(args, *update.PriceETH)
		argNum++
	}
	if update.PriceNEXUS != nil {
		query += fmt.Sprintf(", price_nexus = $%d", argNum)
		args = append(args, *update.PriceNEXUS)
		argNum++
	}
	if update.MarkupPercent != nil {
		query += fmt.Sprintf(", markup_percent = $%d", argNum)
		args = append(args, *update.MarkupPercent)
		argNum++
	}
	if update.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argNum)
		args = append(args, *update.IsActive)
	}

	query += " WHERE service_code = $1"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating pricing for %s: %w", serviceCode, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrPricingNotFound
	}

	return nil
}

// pricingExists checks if pricing exists for a service code
func (r *PostgresPricingRepo) pricingExists(ctx context.Context, serviceCode string) (bool, error) {
	query := "SELECT EXISTS(SELECT 1 FROM pricing WHERE service_code = $1)"
	var exists bool
	err := r.db.QueryRowContext(ctx, query, serviceCode).Scan(&exists)
	if err != nil {
		return false, fmt.Errorf("checking pricing exists: %w", err)
	}
	return exists, nil
}

// GetPaymentMethod retrieves a payment method by code
func (r *PostgresPricingRepo) GetPaymentMethod(ctx context.Context, methodCode string) (*repository.PaymentMethod, error) {
	query := `
		SELECT id, method_code, method_name, is_active, processor_config,
		       min_amount_usd, max_amount_usd, fee_percent, display_order,
		       created_at, updated_at
		FROM payment_methods
		WHERE method_code = $1
	`

	pm := &repository.PaymentMethod{}
	var configJSON []byte
	err := r.db.QueryRowContext(ctx, query, methodCode).Scan(
		&pm.ID,
		&pm.MethodCode,
		&pm.MethodName,
		&pm.IsActive,
		&configJSON,
		&pm.MinAmountUSD,
		&pm.MaxAmountUSD,
		&pm.FeePercent,
		&pm.DisplayOrder,
		&pm.CreatedAt,
		&pm.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrPaymentMethodNotFound
		}
		return nil, fmt.Errorf("getting payment method %s: %w", methodCode, err)
	}

	// Parse JSONB config
	if configJSON != nil {
		if err := json.Unmarshal(configJSON, &pm.ProcessorConfig); err != nil {
			return nil, fmt.Errorf("parsing processor config: %w", err)
		}
	}

	return pm, nil
}

// ListPaymentMethods retrieves all payment methods
func (r *PostgresPricingRepo) ListPaymentMethods(ctx context.Context, activeOnly bool) ([]*repository.PaymentMethod, error) {
	query := `
		SELECT id, method_code, method_name, is_active, processor_config,
		       min_amount_usd, max_amount_usd, fee_percent, display_order,
		       created_at, updated_at
		FROM payment_methods
	`
	if activeOnly {
		query += " WHERE is_active = true"
	}
	query += " ORDER BY display_order, method_code"

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("listing payment methods: %w", err)
	}
	defer rows.Close()

	var result []*repository.PaymentMethod
	for rows.Next() {
		pm := &repository.PaymentMethod{}
		var configJSON []byte
		err := rows.Scan(
			&pm.ID,
			&pm.MethodCode,
			&pm.MethodName,
			&pm.IsActive,
			&configJSON,
			&pm.MinAmountUSD,
			&pm.MaxAmountUSD,
			&pm.FeePercent,
			&pm.DisplayOrder,
			&pm.CreatedAt,
			&pm.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning payment method row: %w", err)
		}

		if configJSON != nil {
			if err := json.Unmarshal(configJSON, &pm.ProcessorConfig); err != nil {
				return nil, fmt.Errorf("parsing processor config: %w", err)
			}
		}

		result = append(result, pm)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating payment method rows: %w", err)
	}

	return result, nil
}

// UpdatePaymentMethod updates a payment method
func (r *PostgresPricingRepo) UpdatePaymentMethod(ctx context.Context, methodCode string, update *repository.PaymentMethodUpdate) error {
	// Build dynamic update query
	query := "UPDATE payment_methods SET updated_at = NOW()"
	args := []interface{}{methodCode}
	argNum := 2

	if update.IsActive != nil {
		query += fmt.Sprintf(", is_active = $%d", argNum)
		args = append(args, *update.IsActive)
		argNum++
	}
	if update.MinAmountUSD != nil {
		query += fmt.Sprintf(", min_amount_usd = $%d", argNum)
		args = append(args, *update.MinAmountUSD)
		argNum++
	}
	if update.MaxAmountUSD != nil {
		query += fmt.Sprintf(", max_amount_usd = $%d", argNum)
		args = append(args, *update.MaxAmountUSD)
		argNum++
	}
	if update.FeePercent != nil {
		query += fmt.Sprintf(", fee_percent = $%d", argNum)
		args = append(args, *update.FeePercent)
		argNum++
	}
	if update.DisplayOrder != nil {
		query += fmt.Sprintf(", display_order = $%d", argNum)
		args = append(args, *update.DisplayOrder)
	}

	query += " WHERE method_code = $1"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating payment method %s: %w", methodCode, err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrPaymentMethodNotFound
	}

	return nil
}

// GetPricingHistory retrieves pricing change history
func (r *PostgresPricingRepo) GetPricingHistory(ctx context.Context, serviceCode string, limit int) ([]*repository.PricingHistoryEntry, error) {
	query := `
		SELECT h.id, h.pricing_id, h.old_price_usd, h.old_price_eth, h.old_price_nexus,
		       h.old_markup_percent, h.new_price_usd, h.new_price_eth, h.new_price_nexus,
		       h.new_markup_percent, h.changed_by, h.changed_at, h.change_reason
		FROM pricing_history h
		JOIN pricing p ON h.pricing_id = p.id
		WHERE p.service_code = $1
		ORDER BY h.changed_at DESC
		LIMIT $2
	`

	rows, err := r.db.QueryContext(ctx, query, serviceCode, limit)
	if err != nil {
		return nil, fmt.Errorf("getting pricing history: %w", err)
	}
	defer rows.Close()

	var result []*repository.PricingHistoryEntry
	for rows.Next() {
		h := &repository.PricingHistoryEntry{}
		err := rows.Scan(
			&h.ID,
			&h.PricingID,
			&h.OldPriceUSD,
			&h.OldPriceETH,
			&h.OldPriceNEXUS,
			&h.OldMarkupPercent,
			&h.NewPriceUSD,
			&h.NewPriceETH,
			&h.NewPriceNEXUS,
			&h.NewMarkupPercent,
			&h.ChangedBy,
			&h.ChangedAt,
			&h.ChangeReason,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning pricing history row: %w", err)
		}
		result = append(result, h)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating pricing history rows: %w", err)
	}

	return result, nil
}
