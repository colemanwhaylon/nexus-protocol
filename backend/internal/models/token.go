package models

import (
	"time"
)

// TokenInfo represents the token metadata and supply information
type TokenInfo struct {
	Name            string `json:"name"`
	Symbol          string `json:"symbol"`
	Decimals        int    `json:"decimals"`
	TotalSupply     string `json:"total_supply"`
	CirculatingSupply string `json:"circulating_supply"`
	ContractAddress string `json:"contract_address"`
	ChainID         int64  `json:"chain_id"`
	
	// Extended metadata
	Description     string `json:"description,omitempty"`
	Website         string `json:"website,omitempty"`
	Whitepaper      string `json:"whitepaper,omitempty"`
	LogoURI         string `json:"logo_uri,omitempty"`
	
	// Tokenomics
	MaxSupply       string `json:"max_supply,omitempty"`
	BurnedSupply    string `json:"burned_supply,omitempty"`
	LockedSupply    string `json:"locked_supply,omitempty"`
	
	// Market data (if available)
	Price           *float64 `json:"price,omitempty"`
	MarketCap       *float64 `json:"market_cap,omitempty"`
	Volume24h       *float64 `json:"volume_24h,omitempty"`
	PriceChange24h  *float64 `json:"price_change_24h,omitempty"`
	
	// Governance
	VotingPower     bool   `json:"voting_power"`
	SnapshotEnabled bool   `json:"snapshot_enabled"`
	
	LastUpdated     time.Time `json:"last_updated"`
}

// TokenBalance represents a wallet's token balance
type TokenBalance struct {
	Address         string `json:"address"`
	Balance         string `json:"balance"`
	BalanceFormatted string `json:"balance_formatted"`
	StakedBalance   string `json:"staked_balance"`
	LockedBalance   string `json:"locked_balance"`
	VestingBalance  string `json:"vesting_balance"`
	
	// Calculated totals
	TotalBalance    string `json:"total_balance"`
	AvailableBalance string `json:"available_balance"`
	
	// Voting power if governance enabled
	VotingPower     string `json:"voting_power,omitempty"`
	DelegatedTo     string `json:"delegated_to,omitempty"`
	
	LastUpdated     time.Time `json:"last_updated"`
}

// TokenHolder represents a token holder with balance
type TokenHolder struct {
	Address     string  `json:"address"`
	Balance     string  `json:"balance"`
	Percentage  float64 `json:"percentage"`
	Rank        int     `json:"rank"`
}

// TokenTransfer represents a token transfer event
type TokenTransfer struct {
	ID              int64     `json:"id" db:"id"`
	TransactionHash string    `json:"transaction_hash" db:"transaction_hash"`
	BlockNumber     int64     `json:"block_number" db:"block_number"`
	From            string    `json:"from" db:"from_address"`
	To              string    `json:"to" db:"to_address"`
	Amount          string    `json:"amount" db:"amount"`
	Timestamp       time.Time `json:"timestamp" db:"timestamp"`
}

// TokenAllowance represents a spender allowance
type TokenAllowance struct {
	Owner    string `json:"owner"`
	Spender  string `json:"spender"`
	Allowance string `json:"allowance"`
}

// TokenApprovalRequest represents a request to approve token spending
type TokenApprovalRequest struct {
	Owner   string `json:"owner" binding:"required,eth_addr"`
	Spender string `json:"spender" binding:"required,eth_addr"`
	Amount  string `json:"amount" binding:"required,numeric"`
}

// TokenTransferRequest represents a request to transfer tokens
type TokenTransferRequest struct {
	From   string `json:"from" binding:"required,eth_addr"`
	To     string `json:"to" binding:"required,eth_addr"`
	Amount string `json:"amount" binding:"required,numeric"`
}

// PaginatedResponse is a generic paginated response wrapper
type PaginatedResponse[T any] struct {
	Data       []T   `json:"data"`
	Total      int64 `json:"total"`
	Page       int   `json:"page"`
	PageSize   int   `json:"page_size"`
	TotalPages int   `json:"total_pages"`
	HasNext    bool  `json:"has_next"`
	HasPrev    bool  `json:"has_prev"`
}

// ErrorResponse represents an API error response
type ErrorResponse struct {
	Error   string `json:"error"`
	Code    string `json:"code,omitempty"`
	Details string `json:"details,omitempty"`
}
