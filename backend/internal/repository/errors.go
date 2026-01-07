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

	// Governance config errors
	ErrGovernanceConfigNotFound = errors.New("governance config not found")
	ErrGovernanceConfigInactive = errors.New("governance config is inactive")
	ErrInvalidConfigKey         = errors.New("invalid governance config key")

	// App config errors
	ErrAppConfigNotFound  = errors.New("app config not found")
	ErrAppConfigInactive  = errors.New("app config is inactive")
	ErrInvalidNamespace   = errors.New("invalid app config namespace")
	ErrInvalidValueType   = errors.New("invalid app config value type")

	// Contract address errors
	ErrNetworkNotFound          = errors.New("network configuration not found")
	ErrNetworkNotActive         = errors.New("network is not active")
	ErrContractMappingNotFound  = errors.New("contract mapping not found")
	ErrContractAddressNotFound  = errors.New("contract address not found")
	ErrContractAlreadyDeployed  = errors.New("contract already deployed on this chain")
	ErrInvalidChainID           = errors.New("invalid chain ID")

	// General errors
	ErrInvalidAddress      = errors.New("invalid ethereum address")
	ErrUnauthorized        = errors.New("unauthorized operation")
	ErrDatabaseError       = errors.New("database operation failed")
	ErrInvalidInput        = errors.New("invalid input")
)
