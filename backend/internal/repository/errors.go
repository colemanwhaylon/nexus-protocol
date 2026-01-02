// Package repository defines the interfaces for data access
package repository

import "errors"

// Domain errors for repository operations
var (
	// Pricing errors
	ErrPricingNotFound     = errors.New("pricing not found")
	ErrPricingInactive     = errors.New("pricing is inactive")
	ErrInvalidServiceCode  = errors.New("invalid service code")

	// Payment method errors
	ErrPaymentMethodNotFound = errors.New("payment method not found")
	ErrPaymentMethodInactive = errors.New("payment method is inactive")
	ErrInvalidMethodCode     = errors.New("invalid payment method code")

	// Payment errors
	ErrPaymentNotFound     = errors.New("payment not found")
	ErrPaymentAlreadyPaid  = errors.New("payment already completed")
	ErrPaymentExpired      = errors.New("payment session expired")
	ErrPaymentFailed       = errors.New("payment processing failed")
	ErrInvalidPaymentState = errors.New("invalid payment state transition")

	// KYC verification errors
	ErrKYCNotFound       = errors.New("kyc verification not found")
	ErrKYCAlreadyExists  = errors.New("kyc verification already exists")
	ErrKYCAlreadyPending = errors.New("kyc verification already pending")
	ErrKYCExpired        = errors.New("kyc verification expired")

	// Meta-transaction errors
	ErrMetaTxNotFound       = errors.New("meta-transaction not found")
	ErrMetaTxAlreadyExists  = errors.New("meta-transaction already exists")
	ErrMetaTxExpired        = errors.New("meta-transaction deadline expired")
	ErrMetaTxInvalidNonce   = errors.New("invalid meta-transaction nonce")
	ErrMetaTxInvalidSig     = errors.New("invalid meta-transaction signature")
	ErrMetaTxAlreadyRelayed = errors.New("meta-transaction already relayed")

	// General errors
	ErrInvalidAddress      = errors.New("invalid ethereum address")
	ErrUnauthorized        = errors.New("unauthorized operation")
	ErrDatabaseError       = errors.New("database operation failed")
	ErrInvalidInput        = errors.New("invalid input")
)
