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

// Ensure PostgresPaymentRepo implements PaymentRepository
var _ repository.PaymentRepository = (*PostgresPaymentRepo)(nil)

// PostgresPaymentRepo implements PaymentRepository using PostgreSQL
type PostgresPaymentRepo struct {
	db *sql.DB
}

// NewPostgresPaymentRepo creates a new PostgreSQL payment repository
func NewPostgresPaymentRepo(db *sql.DB) *PostgresPaymentRepo {
	return &PostgresPaymentRepo{db: db}
}

// CreatePayment creates a new payment record
func (r *PostgresPaymentRepo) CreatePayment(ctx context.Context, payment *repository.Payment) error {
	query := `
		INSERT INTO payments (
			service_code, pricing_id, payer_address, payment_method,
			amount_charged, currency, amount_usd, tx_hash,
			stripe_payment_id, stripe_session_id, status
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(ctx, query,
		payment.ServiceCode,
		payment.PricingID,
		payment.PayerAddress,
		payment.PaymentMethod,
		payment.AmountCharged,
		payment.Currency,
		payment.AmountUSD,
		payment.TxHash,
		payment.StripePaymentID,
		payment.StripeSessionID,
		payment.Status,
	).Scan(&payment.ID, &payment.CreatedAt, &payment.UpdatedAt)

	if err != nil {
		return fmt.Errorf("creating payment: %w", err)
	}

	return nil
}

// GetPayment retrieves a payment by ID
func (r *PostgresPaymentRepo) GetPayment(ctx context.Context, id string) (*repository.Payment, error) {
	query := `
		SELECT id, service_code, pricing_id, payer_address, payment_method,
		       amount_charged, currency, amount_usd, tx_hash,
		       stripe_payment_id, stripe_session_id, status, error_message,
		       created_at, updated_at, completed_at
		FROM payments
		WHERE id = $1
	`

	p := &repository.Payment{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&p.ID,
		&p.ServiceCode,
		&p.PricingID,
		&p.PayerAddress,
		&p.PaymentMethod,
		&p.AmountCharged,
		&p.Currency,
		&p.AmountUSD,
		&p.TxHash,
		&p.StripePaymentID,
		&p.StripeSessionID,
		&p.Status,
		&p.ErrorMessage,
		&p.CreatedAt,
		&p.UpdatedAt,
		&p.CompletedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrPaymentNotFound
		}
		return nil, fmt.Errorf("getting payment %s: %w", id, err)
	}

	return p, nil
}

// GetPaymentByStripeSession retrieves a payment by Stripe session ID
func (r *PostgresPaymentRepo) GetPaymentByStripeSession(ctx context.Context, sessionID string) (*repository.Payment, error) {
	query := `
		SELECT id, service_code, pricing_id, payer_address, payment_method,
		       amount_charged, currency, amount_usd, tx_hash,
		       stripe_payment_id, stripe_session_id, status, error_message,
		       created_at, updated_at, completed_at
		FROM payments
		WHERE stripe_session_id = $1
	`

	p := &repository.Payment{}
	err := r.db.QueryRowContext(ctx, query, sessionID).Scan(
		&p.ID,
		&p.ServiceCode,
		&p.PricingID,
		&p.PayerAddress,
		&p.PaymentMethod,
		&p.AmountCharged,
		&p.Currency,
		&p.AmountUSD,
		&p.TxHash,
		&p.StripePaymentID,
		&p.StripeSessionID,
		&p.Status,
		&p.ErrorMessage,
		&p.CreatedAt,
		&p.UpdatedAt,
		&p.CompletedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrPaymentNotFound
		}
		return nil, fmt.Errorf("getting payment by session %s: %w", sessionID, err)
	}

	return p, nil
}

// UpdatePaymentStatus updates the status of a payment
func (r *PostgresPaymentRepo) UpdatePaymentStatus(ctx context.Context, id string, status repository.PaymentStatus, details *repository.PaymentStatusUpdate) error {
	query := "UPDATE payments SET status = $2"
	args := []interface{}{id, status}
	argNum := 3

	if status == repository.PaymentStatusCompleted {
		query += ", completed_at = NOW()"
	}

	if details != nil {
		if details.TxHash != nil {
			query += fmt.Sprintf(", tx_hash = $%d", argNum)
			args = append(args, *details.TxHash)
			argNum++
		}
		if details.StripePaymentID != nil {
			query += fmt.Sprintf(", stripe_payment_id = $%d", argNum)
			args = append(args, *details.StripePaymentID)
			argNum++
		}
		if details.ErrorMessage != nil {
			query += fmt.Sprintf(", error_message = $%d", argNum)
			args = append(args, *details.ErrorMessage)
		}
	}

	query += " WHERE id = $1"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating payment status: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrPaymentNotFound
	}

	return nil
}

// ListPayments lists payments with filtering
func (r *PostgresPaymentRepo) ListPayments(ctx context.Context, filter repository.PaymentFilter, page repository.Pagination) ([]*repository.Payment, int64, error) {
	// Build where clause
	where := []string{"1=1"}
	args := []interface{}{}
	argNum := 1

	if filter.PayerAddress != "" {
		where = append(where, fmt.Sprintf("payer_address = $%d", argNum))
		args = append(args, filter.PayerAddress)
		argNum++
	}
	if filter.ServiceCode != "" {
		where = append(where, fmt.Sprintf("service_code = $%d", argNum))
		args = append(args, filter.ServiceCode)
		argNum++
	}
	if filter.PaymentMethod != "" {
		where = append(where, fmt.Sprintf("payment_method = $%d", argNum))
		args = append(args, filter.PaymentMethod)
		argNum++
	}
	if filter.Status != "" {
		where = append(where, fmt.Sprintf("status = $%d", argNum))
		args = append(args, filter.Status)
		argNum++
	}

	whereClause := "WHERE " + join(where, " AND ")

	// Count total
	countQuery := "SELECT COUNT(*) FROM payments " + whereClause
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("counting payments: %w", err)
	}

	// Get page
	if page.PageSize <= 0 {
		page.PageSize = 20
	}
	if page.Page <= 0 {
		page.Page = 1
	}
	offset := (page.Page - 1) * page.PageSize

	query := fmt.Sprintf(`
		SELECT id, service_code, pricing_id, payer_address, payment_method,
		       amount_charged, currency, amount_usd, tx_hash,
		       stripe_payment_id, stripe_session_id, status, error_message,
		       created_at, updated_at, completed_at
		FROM payments
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	args = append(args, page.PageSize, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("listing payments: %w", err)
	}
	defer rows.Close()

	var result []*repository.Payment
	for rows.Next() {
		p := &repository.Payment{}
		err := rows.Scan(
			&p.ID,
			&p.ServiceCode,
			&p.PricingID,
			&p.PayerAddress,
			&p.PaymentMethod,
			&p.AmountCharged,
			&p.Currency,
			&p.AmountUSD,
			&p.TxHash,
			&p.StripePaymentID,
			&p.StripeSessionID,
			&p.Status,
			&p.ErrorMessage,
			&p.CreatedAt,
			&p.UpdatedAt,
			&p.CompletedAt,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scanning payment row: %w", err)
		}
		result = append(result, p)
	}

	return result, total, nil
}

// CreateKYCVerification creates a new KYC verification record
func (r *PostgresPaymentRepo) CreateKYCVerification(ctx context.Context, v *repository.KYCVerification) error {
	query := `
		INSERT INTO kyc_verifications (
			payment_id, user_address, sumsub_applicant_id, status
		) VALUES ($1, $2, $3, $4)
		RETURNING id, created_at, updated_at
	`

	err := r.db.QueryRowContext(ctx, query,
		v.PaymentID,
		v.UserAddress,
		v.SumsubApplicantID,
		v.Status,
	).Scan(&v.ID, &v.CreatedAt, &v.UpdatedAt)

	if err != nil {
		return fmt.Errorf("creating kyc verification: %w", err)
	}

	return nil
}

// GetKYCVerification retrieves a KYC verification by ID
func (r *PostgresPaymentRepo) GetKYCVerification(ctx context.Context, id string) (*repository.KYCVerification, error) {
	return r.getKYCVerificationBy(ctx, "id", id)
}

// GetKYCVerificationByAddress retrieves a KYC verification by user address
func (r *PostgresPaymentRepo) GetKYCVerificationByAddress(ctx context.Context, address string) (*repository.KYCVerification, error) {
	return r.getKYCVerificationBy(ctx, "user_address", address)
}

// GetKYCVerificationByApplicant retrieves a KYC verification by Sumsub applicant ID
func (r *PostgresPaymentRepo) GetKYCVerificationByApplicant(ctx context.Context, applicantID string) (*repository.KYCVerification, error) {
	return r.getKYCVerificationBy(ctx, "sumsub_applicant_id", applicantID)
}

func (r *PostgresPaymentRepo) getKYCVerificationBy(ctx context.Context, field, value string) (*repository.KYCVerification, error) {
	query := fmt.Sprintf(`
		SELECT id, payment_id, user_address, sumsub_applicant_id, sumsub_inspection_id,
		       sumsub_review_status, sumsub_review_result, status, whitelist_tx_hash,
		       created_at, updated_at, submitted_at, verified_at, rejected_at
		FROM kyc_verifications
		WHERE %s = $1
		ORDER BY created_at DESC
		LIMIT 1
	`, field)

	v := &repository.KYCVerification{}
	var reviewResultJSON []byte
	err := r.db.QueryRowContext(ctx, query, value).Scan(
		&v.ID,
		&v.PaymentID,
		&v.UserAddress,
		&v.SumsubApplicantID,
		&v.SumsubInspectionID,
		&v.SumsubReviewStatus,
		&reviewResultJSON,
		&v.Status,
		&v.WhitelistTxHash,
		&v.CreatedAt,
		&v.UpdatedAt,
		&v.SubmittedAt,
		&v.VerifiedAt,
		&v.RejectedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrKYCNotFound
		}
		return nil, fmt.Errorf("getting kyc verification: %w", err)
	}

	if reviewResultJSON != nil {
		if err := json.Unmarshal(reviewResultJSON, &v.SumsubReviewResult); err != nil {
			return nil, fmt.Errorf("parsing review result: %w", err)
		}
	}

	return v, nil
}

// UpdateKYCVerification updates a KYC verification record
func (r *PostgresPaymentRepo) UpdateKYCVerification(ctx context.Context, id string, update *repository.KYCVerificationUpdate) error {
	query := "UPDATE kyc_verifications SET updated_at = NOW()"
	args := []interface{}{id}
	argNum := 2

	if update.SumsubApplicantID != nil {
		query += fmt.Sprintf(", sumsub_applicant_id = $%d", argNum)
		args = append(args, *update.SumsubApplicantID)
		argNum++
	}
	if update.SumsubInspectionID != nil {
		query += fmt.Sprintf(", sumsub_inspection_id = $%d", argNum)
		args = append(args, *update.SumsubInspectionID)
		argNum++
	}
	if update.SumsubReviewStatus != nil {
		query += fmt.Sprintf(", sumsub_review_status = $%d", argNum)
		args = append(args, *update.SumsubReviewStatus)
		argNum++
	}
	if update.SumsubReviewResult != nil {
		resultJSON, err := json.Marshal(update.SumsubReviewResult)
		if err != nil {
			return fmt.Errorf("marshaling review result: %w", err)
		}
		query += fmt.Sprintf(", sumsub_review_result = $%d", argNum)
		args = append(args, resultJSON)
		argNum++
	}
	if update.Status != nil {
		query += fmt.Sprintf(", status = $%d", argNum)
		args = append(args, *update.Status)

		// Update timestamp fields based on status
		switch *update.Status {
		case repository.KYCStatusSubmitted:
			query += ", submitted_at = NOW()"
		case repository.KYCStatusApproved:
			query += ", verified_at = NOW()"
		case repository.KYCStatusRejected:
			query += ", rejected_at = NOW()"
		}
		argNum++
	}
	if update.WhitelistTxHash != nil {
		query += fmt.Sprintf(", whitelist_tx_hash = $%d", argNum)
		args = append(args, *update.WhitelistTxHash)
	}

	query += " WHERE id = $1"

	result, err := r.db.ExecContext(ctx, query, args...)
	if err != nil {
		return fmt.Errorf("updating kyc verification: %w", err)
	}

	rows, _ := result.RowsAffected()
	if rows == 0 {
		return repository.ErrKYCNotFound
	}

	return nil
}

// ListKYCVerifications lists KYC verifications with filtering
func (r *PostgresPaymentRepo) ListKYCVerifications(ctx context.Context, filter repository.KYCVerificationFilter, page repository.Pagination) ([]*repository.KYCVerification, int64, error) {
	where := []string{"1=1"}
	args := []interface{}{}
	argNum := 1

	if filter.UserAddress != "" {
		where = append(where, fmt.Sprintf("user_address = $%d", argNum))
		args = append(args, filter.UserAddress)
		argNum++
	}
	if filter.Status != "" {
		where = append(where, fmt.Sprintf("status = $%d", argNum))
		args = append(args, filter.Status)
		argNum++
	}

	whereClause := "WHERE " + join(where, " AND ")

	// Count total
	countQuery := "SELECT COUNT(*) FROM kyc_verifications " + whereClause
	var total int64
	if err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total); err != nil {
		return nil, 0, fmt.Errorf("counting verifications: %w", err)
	}

	// Get page
	if page.PageSize <= 0 {
		page.PageSize = 20
	}
	if page.Page <= 0 {
		page.Page = 1
	}
	offset := (page.Page - 1) * page.PageSize

	query := fmt.Sprintf(`
		SELECT id, payment_id, user_address, sumsub_applicant_id, sumsub_inspection_id,
		       sumsub_review_status, sumsub_review_result, status, whitelist_tx_hash,
		       created_at, updated_at, submitted_at, verified_at, rejected_at
		FROM kyc_verifications
		%s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, whereClause, argNum, argNum+1)

	args = append(args, page.PageSize, offset)

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, 0, fmt.Errorf("listing verifications: %w", err)
	}
	defer rows.Close()

	var result []*repository.KYCVerification
	for rows.Next() {
		v := &repository.KYCVerification{}
		var reviewResultJSON []byte
		err := rows.Scan(
			&v.ID,
			&v.PaymentID,
			&v.UserAddress,
			&v.SumsubApplicantID,
			&v.SumsubInspectionID,
			&v.SumsubReviewStatus,
			&reviewResultJSON,
			&v.Status,
			&v.WhitelistTxHash,
			&v.CreatedAt,
			&v.UpdatedAt,
			&v.SubmittedAt,
			&v.VerifiedAt,
			&v.RejectedAt,
		)
		if err != nil {
			return nil, 0, fmt.Errorf("scanning verification row: %w", err)
		}

		if reviewResultJSON != nil {
			json.Unmarshal(reviewResultJSON, &v.SumsubReviewResult)
		}

		result = append(result, v)
	}

	return result, total, nil
}

// join is a helper to join strings with a separator
func join(strs []string, sep string) string {
	if len(strs) == 0 {
		return ""
	}
	result := strs[0]
	for _, s := range strs[1:] {
		result += sep + s
	}
	return result
}
