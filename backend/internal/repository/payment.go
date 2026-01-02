// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"time"
)

// PaymentRepository defines the contract for payment data operations
type PaymentRepository interface {
	// Payment CRUD
	CreatePayment(ctx context.Context, payment *Payment) error
	GetPayment(ctx context.Context, id string) (*Payment, error)
	GetPaymentByStripeSession(ctx context.Context, sessionID string) (*Payment, error)
	UpdatePaymentStatus(ctx context.Context, id string, status PaymentStatus, details *PaymentStatusUpdate) error
	ListPayments(ctx context.Context, filter PaymentFilter, page Pagination) ([]*Payment, int64, error)

	// KYC Verification
	CreateKYCVerification(ctx context.Context, verification *KYCVerification) error
	GetKYCVerification(ctx context.Context, id string) (*KYCVerification, error)
	GetKYCVerificationByAddress(ctx context.Context, address string) (*KYCVerification, error)
	GetKYCVerificationByApplicant(ctx context.Context, applicantID string) (*KYCVerification, error)
	UpdateKYCVerification(ctx context.Context, id string, update *KYCVerificationUpdate) error
	ListKYCVerifications(ctx context.Context, filter KYCVerificationFilter, page Pagination) ([]*KYCVerification, int64, error)
}

// PaymentStatus represents payment states
type PaymentStatus string

const (
	PaymentStatusPending    PaymentStatus = "pending"
	PaymentStatusProcessing PaymentStatus = "processing"
	PaymentStatusCompleted  PaymentStatus = "completed"
	PaymentStatusFailed     PaymentStatus = "failed"
	PaymentStatusRefunded   PaymentStatus = "refunded"
	PaymentStatusCancelled  PaymentStatus = "cancelled"
)

// Payment represents a payment transaction
type Payment struct {
	ID              string        `json:"id" db:"id"`
	ServiceCode     string        `json:"service_code" db:"service_code"`
	PricingID       *string       `json:"pricing_id" db:"pricing_id"`
	PayerAddress    string        `json:"payer_address" db:"payer_address"`
	PaymentMethod   string        `json:"payment_method" db:"payment_method"`
	AmountCharged   float64       `json:"amount_charged" db:"amount_charged"`
	Currency        string        `json:"currency" db:"currency"`
	AmountUSD       *float64      `json:"amount_usd" db:"amount_usd"`
	TxHash          *string       `json:"tx_hash,omitempty" db:"tx_hash"`
	StripePaymentID *string       `json:"stripe_payment_id,omitempty" db:"stripe_payment_id"`
	StripeSessionID *string       `json:"stripe_session_id,omitempty" db:"stripe_session_id"`
	Status          PaymentStatus `json:"status" db:"status"`
	ErrorMessage    *string       `json:"error_message,omitempty" db:"error_message"`
	CreatedAt       time.Time     `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time     `json:"updated_at" db:"updated_at"`
	CompletedAt     *time.Time    `json:"completed_at,omitempty" db:"completed_at"`
}

// PaymentStatusUpdate contains update details for payment status
type PaymentStatusUpdate struct {
	TxHash          *string `json:"tx_hash,omitempty"`
	StripePaymentID *string `json:"stripe_payment_id,omitempty"`
	ErrorMessage    *string `json:"error_message,omitempty"`
}

// PaymentFilter defines filtering options for listing payments
type PaymentFilter struct {
	PayerAddress  string
	ServiceCode   string
	PaymentMethod string
	Status        PaymentStatus
}

// Pagination defines pagination parameters
type Pagination struct {
	Page     int
	PageSize int
}

// KYCVerificationStatus represents KYC verification states
type KYCVerificationStatus string

const (
	KYCStatusPending         KYCVerificationStatus = "pending"
	KYCStatusPaymentRequired KYCVerificationStatus = "payment_required"
	KYCStatusSubmitted       KYCVerificationStatus = "submitted"
	KYCStatusInReview        KYCVerificationStatus = "in_review"
	KYCStatusApproved        KYCVerificationStatus = "approved"
	KYCStatusRejected        KYCVerificationStatus = "rejected"
	KYCStatusExpired         KYCVerificationStatus = "expired"
)

// KYCVerification represents a KYC verification request
type KYCVerification struct {
	ID                  string                `json:"id" db:"id"`
	PaymentID           *string               `json:"payment_id" db:"payment_id"`
	UserAddress         string                `json:"user_address" db:"user_address"`
	SumsubApplicantID   *string               `json:"sumsub_applicant_id" db:"sumsub_applicant_id"`
	SumsubInspectionID  *string               `json:"sumsub_inspection_id" db:"sumsub_inspection_id"`
	SumsubReviewStatus  *string               `json:"sumsub_review_status" db:"sumsub_review_status"`
	SumsubReviewResult  any                   `json:"sumsub_review_result" db:"sumsub_review_result"`
	Status              KYCVerificationStatus `json:"status" db:"status"`
	WhitelistTxHash     *string               `json:"whitelist_tx_hash,omitempty" db:"whitelist_tx_hash"`
	CreatedAt           time.Time             `json:"created_at" db:"created_at"`
	UpdatedAt           time.Time             `json:"updated_at" db:"updated_at"`
	SubmittedAt         *time.Time            `json:"submitted_at,omitempty" db:"submitted_at"`
	VerifiedAt          *time.Time            `json:"verified_at,omitempty" db:"verified_at"`
	RejectedAt          *time.Time            `json:"rejected_at,omitempty" db:"rejected_at"`
}

// KYCVerificationUpdate contains update fields for KYC verification
type KYCVerificationUpdate struct {
	SumsubApplicantID  *string               `json:"sumsub_applicant_id,omitempty"`
	SumsubInspectionID *string               `json:"sumsub_inspection_id,omitempty"`
	SumsubReviewStatus *string               `json:"sumsub_review_status,omitempty"`
	SumsubReviewResult any                   `json:"sumsub_review_result,omitempty"`
	Status             *KYCVerificationStatus `json:"status,omitempty"`
	WhitelistTxHash    *string               `json:"whitelist_tx_hash,omitempty"`
}

// KYCVerificationFilter defines filtering options for listing verifications
type KYCVerificationFilter struct {
	UserAddress string
	Status      KYCVerificationStatus
}
