package models

import (
	"time"
)

// StakeStatus represents the status of a stake
type StakeStatus string

const (
	StakeStatusActive    StakeStatus = "active"
	StakeStatusUnstaking StakeStatus = "unstaking"
	StakeStatusWithdrawn StakeStatus = "withdrawn"
	StakeStatusSlashed   StakeStatus = "slashed"
)

// Stake represents a user's staking position
type Stake struct {
	ID              int64       `json:"id" db:"id"`
	Address         string      `json:"address" db:"address"`                   // User wallet address
	Amount          string      `json:"amount" db:"amount"`                     // Staked amount (stored as string for precision)
	Shares          string      `json:"shares" db:"shares"`                     // Share tokens received
	Status          StakeStatus `json:"status" db:"status"`                     // Current stake status
	DelegatedTo     string      `json:"delegated_to,omitempty" db:"delegated_to"` // Validator address if delegated
	UnstakeInitAt   *time.Time  `json:"unstake_init_at,omitempty" db:"unstake_init_at"` // When unstaking was initiated
	UnstakeReadyAt  *time.Time  `json:"unstake_ready_at,omitempty" db:"unstake_ready_at"` // When unstake is ready to withdraw
	CreatedAt       time.Time   `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time   `json:"updated_at" db:"updated_at"`
}

// StakeRequest represents a request to stake tokens
type StakeRequest struct {
	Address     string `json:"address" binding:"required,eth_addr"`
	Amount      string `json:"amount" binding:"required,numeric"`
	DelegatedTo string `json:"delegated_to,omitempty" binding:"omitempty,eth_addr"`
}

// UnstakeRequest represents a request to unstake tokens
type UnstakeRequest struct {
	Address string `json:"address" binding:"required,eth_addr"`
	Shares  string `json:"shares" binding:"required,numeric"`
}

// StakeInfo represents aggregated staking information
type StakeInfo struct {
	TotalStaked       string  `json:"total_staked"`
	TotalShares       string  `json:"total_shares"`
	TotalStakers      int64   `json:"total_stakers"`
	APY               float64 `json:"apy"`
	MinStake          string  `json:"min_stake"`
	UnstakingPeriod   int     `json:"unstaking_period_days"`
	RewardsPerBlock   string  `json:"rewards_per_block"`
	LastRewardBlock   int64   `json:"last_reward_block"`
	AccRewardsPerShare string `json:"acc_rewards_per_share"`
}

// UserStakeInfo represents a user's staking information
type UserStakeInfo struct {
	Address         string      `json:"address"`
	Stakes          []Stake     `json:"stakes"`
	TotalStaked     string      `json:"total_staked"`
	TotalShares     string      `json:"total_shares"`
	PendingRewards  string      `json:"pending_rewards"`
	UnstakingAmount string      `json:"unstaking_amount"`
	WithdrawableAt  *time.Time  `json:"withdrawable_at,omitempty"`
}

// StakeResponse represents the response after a stake/unstake operation
type StakeResponse struct {
	TransactionHash string    `json:"transaction_hash"`
	Stake           *Stake    `json:"stake,omitempty"`
	Message         string    `json:"message"`
	Timestamp       time.Time `json:"timestamp"`
}
