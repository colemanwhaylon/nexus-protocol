// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"time"
)

// RelayerRepository defines the contract for meta-transaction data operations
type RelayerRepository interface {
	// Meta-transaction CRUD
	CreateMetaTx(ctx context.Context, tx *MetaTransaction) error
	GetMetaTx(ctx context.Context, id string) (*MetaTransaction, error)
	GetMetaTxByHash(ctx context.Context, txHash string) (*MetaTransaction, error)
	UpdateMetaTxStatus(ctx context.Context, id string, update *MetaTxStatusUpdate) error
	ListMetaTx(ctx context.Context, filter MetaTxFilter, page Pagination) ([]*MetaTransaction, int64, error)

	// Nonce management
	GetNextNonce(ctx context.Context, fromAddress string) (uint64, error)

	// Pending transaction management
	GetPendingMetaTxs(ctx context.Context, limit int) ([]*MetaTransaction, error)
	GetExpiredMetaTxs(ctx context.Context, limit int) ([]*MetaTransaction, error)
}

// MetaTxStatus represents meta-transaction states
type MetaTxStatus string

const (
	MetaTxStatusPending   MetaTxStatus = "pending"
	MetaTxStatusSubmitted MetaTxStatus = "submitted"
	MetaTxStatusConfirmed MetaTxStatus = "confirmed"
	MetaTxStatusFailed    MetaTxStatus = "failed"
	MetaTxStatusExpired   MetaTxStatus = "expired"
	MetaTxStatusCancelled MetaTxStatus = "cancelled"
)

// MetaTransaction represents an ERC-2771 meta-transaction request
type MetaTransaction struct {
	ID           string       `json:"id" db:"id"`
	FromAddress  string       `json:"from_address" db:"from_address"`
	ToAddress    string       `json:"to_address" db:"to_address"`
	FunctionName string       `json:"function_name" db:"function_name"`
	Calldata     string       `json:"calldata" db:"calldata"`
	Value        string       `json:"value" db:"value"`
	GasLimit     uint64       `json:"gas_limit" db:"gas_limit"`
	Nonce        uint64       `json:"nonce" db:"nonce"`
	Deadline     time.Time    `json:"deadline" db:"deadline"`
	Signature    string       `json:"signature" db:"signature"`
	Status       MetaTxStatus `json:"status" db:"status"`
	TxHash       *string      `json:"tx_hash,omitempty" db:"tx_hash"`
	GasUsed      *uint64      `json:"gas_used,omitempty" db:"gas_used"`
	GasPrice     *string      `json:"gas_price,omitempty" db:"gas_price"`
	RelayCostETH *string      `json:"relay_cost_eth,omitempty" db:"relay_cost_eth"`
	ErrorMessage *string      `json:"error_message,omitempty" db:"error_message"`
	RetryCount   int          `json:"retry_count" db:"retry_count"`
	CreatedAt    time.Time    `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time    `json:"updated_at" db:"updated_at"`
	SubmittedAt  *time.Time   `json:"submitted_at,omitempty" db:"submitted_at"`
	ConfirmedAt  *time.Time   `json:"confirmed_at,omitempty" db:"confirmed_at"`
}

// MetaTxStatusUpdate contains update details for meta-transaction status
type MetaTxStatusUpdate struct {
	Status       MetaTxStatus `json:"status"`
	TxHash       *string      `json:"tx_hash,omitempty"`
	GasUsed      *uint64      `json:"gas_used,omitempty"`
	GasPrice     *string      `json:"gas_price,omitempty"`
	RelayCostETH *string      `json:"relay_cost_eth,omitempty"`
	ErrorMessage *string      `json:"error_message,omitempty"`
}

// MetaTxFilter defines filtering options for listing meta-transactions
type MetaTxFilter struct {
	FromAddress  string
	ToAddress    string
	FunctionName string
	Status       MetaTxStatus
}

// ERC-2771 ForwardRequest as defined in NexusForwarder contract
type ForwardRequest struct {
	From     string `json:"from"`
	To       string `json:"to"`
	Value    string `json:"value"`
	Gas      uint64 `json:"gas"`
	Nonce    uint64 `json:"nonce"`
	Deadline uint64 `json:"deadline"`
	Data     string `json:"data"`
}
