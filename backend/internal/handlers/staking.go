package handlers

import (
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// StakingHandler handles staking-related API endpoints
type StakingHandler struct {
	logger *zap.Logger
	// In production, this would be a blockchain client interface
	// For demo purposes, we use in-memory storage
	positions map[string]*StakingPosition
}

// StakingPosition represents a user's staking position
type StakingPosition struct {
	Address       string    `json:"address"`
	StakedAmount  string    `json:"staked_amount"`
	StakedAt      time.Time `json:"staked_at"`
	UnbondingAt   *time.Time `json:"unbonding_at,omitempty"`
	UnbondingAmt  string    `json:"unbonding_amount,omitempty"`
	Delegatee     string    `json:"delegatee,omitempty"`
	PendingReward string    `json:"pending_reward"`
	LastClaimAt   time.Time `json:"last_claim_at"`
}

// StakeRequest represents a stake request body
type StakeRequest struct {
	Address   string `json:"address" binding:"required"`
	Amount    string `json:"amount" binding:"required"`
	Delegatee string `json:"delegatee,omitempty"`
}

// UnstakeRequest represents an unstake request body
type UnstakeRequest struct {
	Address string `json:"address" binding:"required"`
	Amount  string `json:"amount" binding:"required"`
}

// StakeResponse represents a stake operation response
type StakeResponse struct {
	Success       bool   `json:"success"`
	TransactionID string `json:"transaction_id,omitempty"`
	Message       string `json:"message"`
	Position      *StakingPosition `json:"position,omitempty"`
}

// UnstakeResponse represents an unstake operation response
type UnstakeResponse struct {
	Success        bool      `json:"success"`
	TransactionID  string    `json:"transaction_id,omitempty"`
	Message        string    `json:"message"`
	UnbondingEnds  time.Time `json:"unbonding_ends,omitempty"`
	PenaltyApplied bool      `json:"penalty_applied"`
	PenaltyAmount  string    `json:"penalty_amount,omitempty"`
}

// PositionResponse wraps a staking position response
type PositionResponse struct {
	Success  bool             `json:"success"`
	Position *StakingPosition `json:"position,omitempty"`
	Message  string           `json:"message,omitempty"`
}

// NewStakingHandler creates a new staking handler
func NewStakingHandler(logger *zap.Logger) *StakingHandler {
	return &StakingHandler{
		logger:    logger,
		positions: make(map[string]*StakingPosition),
	}
}

// Stake handles POST /api/v1/staking/stake
// @Summary Stake tokens
// @Description Stakes tokens for the given address with optional delegation
// @Tags staking
// @Accept json
// @Produce json
// @Param request body StakeRequest true "Stake request"
// @Success 200 {object} StakeResponse
// @Failure 400 {object} StakeResponse
// @Failure 500 {object} StakeResponse
// @Router /api/v1/staking/stake [post]
func (h *StakingHandler) Stake(c *gin.Context) {
	var req StakeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid stake request", zap.Error(err))
		c.JSON(http.StatusBadRequest, StakeResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate address format (basic Ethereum address validation)
	if !isValidAddress(req.Address) {
		c.JSON(http.StatusBadRequest, StakeResponse{
			Success: false,
			Message: "Invalid Ethereum address format",
		})
		return
	}

	// Validate amount (must be positive number)
	amount, ok := new(big.Int).SetString(req.Amount, 10)
	if !ok || amount.Sign() <= 0 {
		c.JSON(http.StatusBadRequest, StakeResponse{
			Success: false,
			Message: "Invalid stake amount: must be a positive integer",
		})
		return
	}

	// In production, this would:
	// 1. Verify user has sufficient balance
	// 2. Submit transaction to blockchain
	// 3. Wait for confirmation
	// For demo, we simulate the operation

	address := strings.ToLower(req.Address)
	now := time.Now()

	// Get existing position or create new one
	position, exists := h.positions[address]
	if exists {
		// Add to existing stake
		existing, _ := new(big.Int).SetString(position.StakedAmount, 10)
		newAmount := new(big.Int).Add(existing, amount)
		position.StakedAmount = newAmount.String()
	} else {
		position = &StakingPosition{
			Address:       address,
			StakedAmount:  amount.String(),
			StakedAt:      now,
			PendingReward: "0",
			LastClaimAt:   now,
		}
		h.positions[address] = position
	}

	// Set delegatee if provided
	if req.Delegatee != "" && isValidAddress(req.Delegatee) {
		position.Delegatee = strings.ToLower(req.Delegatee)
	}

	h.logger.Info("stake operation completed",
		zap.String("address", address),
		zap.String("amount", req.Amount),
		zap.String("total_staked", position.StakedAmount),
	)

	// Generate mock transaction ID
	txID := generateMockTxID()

	c.JSON(http.StatusOK, StakeResponse{
		Success:       true,
		TransactionID: txID,
		Message:       "Stake operation successful",
		Position:      position,
	})
}

// Unstake handles POST /api/v1/staking/unstake
// @Summary Unstake tokens
// @Description Initiates unstaking process with 7-day unbonding period
// @Tags staking
// @Accept json
// @Produce json
// @Param request body UnstakeRequest true "Unstake request"
// @Success 200 {object} UnstakeResponse
// @Failure 400 {object} UnstakeResponse
// @Failure 404 {object} UnstakeResponse
// @Router /api/v1/staking/unstake [post]
func (h *StakingHandler) Unstake(c *gin.Context) {
	var req UnstakeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid unstake request", zap.Error(err))
		c.JSON(http.StatusBadRequest, UnstakeResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate address format
	if !isValidAddress(req.Address) {
		c.JSON(http.StatusBadRequest, UnstakeResponse{
			Success: false,
			Message: "Invalid Ethereum address format",
		})
		return
	}

	// Validate amount
	amount, ok := new(big.Int).SetString(req.Amount, 10)
	if !ok || amount.Sign() <= 0 {
		c.JSON(http.StatusBadRequest, UnstakeResponse{
			Success: false,
			Message: "Invalid unstake amount: must be a positive integer",
		})
		return
	}

	address := strings.ToLower(req.Address)

	// Check if position exists
	position, exists := h.positions[address]
	if !exists {
		c.JSON(http.StatusNotFound, UnstakeResponse{
			Success: false,
			Message: "No staking position found for this address",
		})
		return
	}

	// Check if sufficient stake
	staked, _ := new(big.Int).SetString(position.StakedAmount, 10)
	if amount.Cmp(staked) > 0 {
		c.JSON(http.StatusBadRequest, UnstakeResponse{
			Success: false,
			Message: "Insufficient staked balance",
		})
		return
	}

	// Calculate penalty if early exit (staked < 24 hours per SEC-002)
	now := time.Now()
	penaltyApplied := false
	penaltyAmount := "0"
	minStakeDuration := 24 * time.Hour

	if now.Sub(position.StakedAt) < minStakeDuration {
		// Apply 5% early exit penalty (SEC-002)
		penaltyBps := big.NewInt(500) // 5% in basis points
		bpsDenom := big.NewInt(10000)
		penalty := new(big.Int).Mul(amount, penaltyBps)
		penalty.Div(penalty, bpsDenom)
		penaltyAmount = penalty.String()
		penaltyApplied = true

		h.logger.Warn("early exit penalty applied",
			zap.String("address", address),
			zap.String("penalty", penaltyAmount),
		)
	}

	// Update position (7-day unbonding period per SEC-002)
	unbondingPeriod := 7 * 24 * time.Hour
	unbondingEnds := now.Add(unbondingPeriod)

	newStaked := new(big.Int).Sub(staked, amount)
	position.StakedAmount = newStaked.String()
	position.UnbondingAt = &now
	position.UnbondingAmt = amount.String()

	h.logger.Info("unstake operation initiated",
		zap.String("address", address),
		zap.String("amount", req.Amount),
		zap.Time("unbonding_ends", unbondingEnds),
		zap.Bool("penalty_applied", penaltyApplied),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, UnstakeResponse{
		Success:        true,
		TransactionID:  txID,
		Message:        "Unstake operation initiated. Tokens will be available after unbonding period.",
		UnbondingEnds:  unbondingEnds,
		PenaltyApplied: penaltyApplied,
		PenaltyAmount:  penaltyAmount,
	})
}

// GetPosition handles GET /api/v1/staking/position/:address
// @Summary Get staking position
// @Description Returns the staking position for a given address
// @Tags staking
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} PositionResponse
// @Failure 400 {object} PositionResponse
// @Failure 404 {object} PositionResponse
// @Router /api/v1/staking/position/{address} [get]
func (h *StakingHandler) GetPosition(c *gin.Context) {
	address := c.Param("address")

	// Validate address format
	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, PositionResponse{
			Success: false,
			Message: "Invalid Ethereum address format",
		})
		return
	}

	address = strings.ToLower(address)

	position, exists := h.positions[address]
	if !exists {
		c.JSON(http.StatusNotFound, PositionResponse{
			Success: false,
			Message: "No staking position found for this address",
		})
		return
	}

	// Calculate pending rewards (simplified simulation)
	// In production, this would query the RewardsDistributor contract
	position.PendingReward = calculatePendingRewards(position)

	h.logger.Debug("position retrieved",
		zap.String("address", address),
		zap.String("staked", position.StakedAmount),
	)

	c.JSON(http.StatusOK, PositionResponse{
		Success:  true,
		Position: position,
	})
}

// Helper functions

// isValidAddress validates Ethereum address format
func isValidAddress(address string) bool {
	if len(address) != 42 {
		return false
	}
	if !strings.HasPrefix(address, "0x") && !strings.HasPrefix(address, "0X") {
		return false
	}
	// Check if remaining characters are valid hex
	for _, c := range address[2:] {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}

// generateMockTxID generates a mock transaction ID for demo purposes
func generateMockTxID() string {
	return "0x" + strings.Repeat("0", 64)[:60] + time.Now().Format("0102150405")
}

// calculatePendingRewards calculates pending rewards (simplified)
func calculatePendingRewards(position *StakingPosition) string {
	// Simplified reward calculation for demo
	// In production, this would query the blockchain
	staked, ok := new(big.Int).SetString(position.StakedAmount, 10)
	if !ok || staked.Sign() <= 0 {
		return "0"
	}

	// 10% APY, calculated per second
	secondsStaked := time.Since(position.LastClaimAt).Seconds()
	yearSeconds := float64(365 * 24 * 60 * 60)
	apy := 0.10

	stakedFloat := new(big.Float).SetInt(staked)
	rewardFloat := new(big.Float).Mul(stakedFloat, big.NewFloat(apy*secondsStaked/yearSeconds))

	reward, _ := rewardFloat.Int(nil)
	return reward.String()
}
