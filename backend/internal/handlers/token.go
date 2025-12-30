package handlers

import (
	"math/big"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// TokenHandler handles token-related API endpoints
type TokenHandler struct {
	logger   *zap.Logger
	// In production, this would be a blockchain client interface
	// For demo purposes, we use in-memory storage
	balances map[string]*big.Int
	// Token metadata
	name     string
	symbol   string
	decimals uint8
	totalSupply *big.Int
}

// TokenInfo represents token metadata
type TokenInfo struct {
	Name        string `json:"name"`
	Symbol      string `json:"symbol"`
	Decimals    uint8  `json:"decimals"`
	TotalSupply string `json:"total_supply"`
	Address     string `json:"contract_address"`
}

// BalanceResponse represents a balance query response
type BalanceResponse struct {
	Success bool   `json:"success"`
	Address string `json:"address"`
	Balance string `json:"balance"`
	Message string `json:"message,omitempty"`
}

// TransferRequest represents a token transfer request
type TransferRequest struct {
	From   string `json:"from" binding:"required"`
	To     string `json:"to" binding:"required"`
	Amount string `json:"amount" binding:"required"`
}

// TransferResponse represents a token transfer response
type TransferResponse struct {
	Success       bool   `json:"success"`
	TransactionID string `json:"transaction_id,omitempty"`
	From          string `json:"from"`
	To            string `json:"to"`
	Amount        string `json:"amount"`
	Message       string `json:"message"`
}

// TokenInfoResponse wraps token info response
type TokenInfoResponse struct {
	Success bool      `json:"success"`
	Token   TokenInfo `json:"token"`
}

// NewTokenHandler creates a new token handler
func NewTokenHandler(logger *zap.Logger) *TokenHandler {
	// Initialize with demo data
	totalSupply, _ := new(big.Int).SetString("100000000000000000000000000", 10) // 100M tokens with 18 decimals

	h := &TokenHandler{
		logger:      logger,
		balances:    make(map[string]*big.Int),
		name:        "Nexus Token",
		symbol:      "NXS",
		decimals:    18,
		totalSupply: totalSupply,
	}

	// Seed some demo balances
	h.seedDemoBalances()

	return h
}

// seedDemoBalances initializes demo balances for testing
func (h *TokenHandler) seedDemoBalances() {
	// Demo treasury address with most of supply
	treasuryBalance, _ := new(big.Int).SetString("80000000000000000000000000", 10) // 80M
	h.balances["0x0000000000000000000000000000000000000001"] = treasuryBalance

	// Demo staking pool
	stakingBalance, _ := new(big.Int).SetString("15000000000000000000000000", 10) // 15M
	h.balances["0x0000000000000000000000000000000000000002"] = stakingBalance

	// Demo user balance
	userBalance, _ := new(big.Int).SetString("5000000000000000000000000", 10) // 5M
	h.balances["0x0000000000000000000000000000000000000003"] = userBalance
}

// GetBalance handles GET /api/v1/token/balance/:address
// @Summary Get token balance
// @Description Returns the NXS token balance for a given address
// @Tags token
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} BalanceResponse
// @Failure 400 {object} BalanceResponse
// @Router /api/v1/token/balance/{address} [get]
func (h *TokenHandler) GetBalance(c *gin.Context) {
	address := c.Param("address")

	// Validate address format
	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, BalanceResponse{
			Success: false,
			Message: "Invalid Ethereum address format",
		})
		return
	}

	address = strings.ToLower(address)

	// Get balance (default to 0 if not found)
	balance, exists := h.balances[address]
	if !exists {
		balance = big.NewInt(0)
	}

	h.logger.Debug("balance retrieved",
		zap.String("address", address),
		zap.String("balance", balance.String()),
	)

	c.JSON(http.StatusOK, BalanceResponse{
		Success: true,
		Address: address,
		Balance: balance.String(),
	})
}

// Transfer handles POST /api/v1/token/transfer
// @Summary Transfer tokens
// @Description Transfers NXS tokens from one address to another
// @Tags token
// @Accept json
// @Produce json
// @Param request body TransferRequest true "Transfer request"
// @Success 200 {object} TransferResponse
// @Failure 400 {object} TransferResponse
// @Failure 403 {object} TransferResponse
// @Router /api/v1/token/transfer [post]
func (h *TokenHandler) Transfer(c *gin.Context) {
	var req TransferRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid transfer request", zap.Error(err))
		c.JSON(http.StatusBadRequest, TransferResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate addresses
	if !isValidAddress(req.From) {
		c.JSON(http.StatusBadRequest, TransferResponse{
			Success: false,
			Message: "Invalid 'from' address format",
		})
		return
	}

	if !isValidAddress(req.To) {
		c.JSON(http.StatusBadRequest, TransferResponse{
			Success: false,
			Message: "Invalid 'to' address format",
		})
		return
	}

	// Validate amount
	amount, ok := new(big.Int).SetString(req.Amount, 10)
	if !ok || amount.Sign() <= 0 {
		c.JSON(http.StatusBadRequest, TransferResponse{
			Success: false,
			Message: "Invalid transfer amount: must be a positive integer",
		})
		return
	}

	from := strings.ToLower(req.From)
	to := strings.ToLower(req.To)

	// Check sender has sufficient balance
	senderBalance, exists := h.balances[from]
	if !exists || senderBalance.Cmp(amount) < 0 {
		c.JSON(http.StatusForbidden, TransferResponse{
			Success: false,
			From:    from,
			To:      to,
			Amount:  req.Amount,
			Message: "Insufficient balance",
		})
		return
	}

	// In production, this would:
	// 1. Verify sender signature
	// 2. Submit transaction to blockchain
	// 3. Wait for confirmation
	// For demo, we simulate the transfer

	// Deduct from sender
	h.balances[from] = new(big.Int).Sub(senderBalance, amount)

	// Add to recipient
	recipientBalance, exists := h.balances[to]
	if !exists {
		recipientBalance = big.NewInt(0)
	}
	h.balances[to] = new(big.Int).Add(recipientBalance, amount)

	h.logger.Info("transfer completed",
		zap.String("from", from),
		zap.String("to", to),
		zap.String("amount", req.Amount),
	)

	// Generate mock transaction ID
	txID := generateMockTxID()

	c.JSON(http.StatusOK, TransferResponse{
		Success:       true,
		TransactionID: txID,
		From:          from,
		To:            to,
		Amount:        req.Amount,
		Message:       "Transfer successful",
	})
}

// GetTokenInfo handles GET /api/v1/token/info
// @Summary Get token information
// @Description Returns NXS token metadata
// @Tags token
// @Produce json
// @Success 200 {object} TokenInfoResponse
// @Router /api/v1/token/info [get]
func (h *TokenHandler) GetTokenInfo(c *gin.Context) {
	c.JSON(http.StatusOK, TokenInfoResponse{
		Success: true,
		Token: TokenInfo{
			Name:        h.name,
			Symbol:      h.symbol,
			Decimals:    h.decimals,
			TotalSupply: h.totalSupply.String(),
			Address:     "0x...", // Would be actual contract address in production
		},
	})
}

// GetTotalSupply handles GET /api/v1/token/supply
// @Summary Get total supply
// @Description Returns the total supply of NXS tokens
// @Tags token
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/token/supply [get]
func (h *TokenHandler) GetTotalSupply(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"total_supply": h.totalSupply.String(),
		"decimals":     h.decimals,
		"timestamp":    time.Now().UTC().Format(time.RFC3339),
	})
}

// GetCirculatingSupply handles GET /api/v1/token/circulating
// @Summary Get circulating supply
// @Description Returns the circulating supply of NXS tokens (total - treasury - staking)
// @Tags token
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/token/circulating [get]
func (h *TokenHandler) GetCirculatingSupply(c *gin.Context) {
	// Calculate circulating supply (total - reserved addresses)
	circulating := new(big.Int).Set(h.totalSupply)

	// Subtract treasury balance
	if treasury, exists := h.balances["0x0000000000000000000000000000000000000001"]; exists {
		circulating.Sub(circulating, treasury)
	}

	// Subtract staking pool balance
	if staking, exists := h.balances["0x0000000000000000000000000000000000000002"]; exists {
		circulating.Sub(circulating, staking)
	}

	c.JSON(http.StatusOK, gin.H{
		"success":            true,
		"circulating_supply": circulating.String(),
		"total_supply":       h.totalSupply.String(),
		"decimals":           h.decimals,
		"timestamp":          time.Now().UTC().Format(time.RFC3339),
	})
}

// Allowance handles GET /api/v1/token/allowance/:owner/:spender
// @Summary Get token allowance
// @Description Returns the amount of tokens approved for spender by owner
// @Tags token
// @Produce json
// @Param owner path string true "Owner address"
// @Param spender path string true "Spender address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/token/allowance/{owner}/{spender} [get]
func (h *TokenHandler) Allowance(c *gin.Context) {
	owner := c.Param("owner")
	spender := c.Param("spender")

	if !isValidAddress(owner) || !isValidAddress(spender) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	// In production, this would query the blockchain
	// For demo, we return 0 (no allowances stored in memory)
	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"owner":     strings.ToLower(owner),
		"spender":   strings.ToLower(spender),
		"allowance": "0",
	})
}
