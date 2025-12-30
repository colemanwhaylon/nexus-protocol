package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"math/big"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// NFTHandler handles NFT-related API endpoints
type NFTHandler struct {
	logger     *zap.Logger
	mu         sync.RWMutex
	tokens     map[string]*NFTToken              // tokenID -> token
	ownership  map[string][]string               // address -> []tokenID
	approvals  map[string]string                 // tokenID -> approved address
	operatorApprovals map[string]map[string]bool // owner -> operator -> approved
	// Collection metadata
	name          string
	symbol        string
	maxSupply     uint64
	totalMinted   uint64
	mintPrice     *big.Int
	revealed      bool
	baseURI       string
	unrevealedURI string
	royaltyBps    uint16 // Royalty in basis points (e.g., 500 = 5%)
	royaltyReceiver string
}

// NFTToken represents an NFT token
type NFTToken struct {
	TokenID     string            `json:"token_id"`
	Owner       string            `json:"owner"`
	Name        string            `json:"name"`
	Description string            `json:"description"`
	Image       string            `json:"image"`
	Attributes  []NFTAttribute    `json:"attributes"`
	Soulbound   bool              `json:"soulbound"`
	MintedAt    time.Time         `json:"minted_at"`
	TransferredAt *time.Time      `json:"transferred_at,omitempty"`
	Metadata    map[string]string `json:"metadata,omitempty"`
}

// NFTAttribute represents an NFT trait
type NFTAttribute struct {
	TraitType   string      `json:"trait_type"`
	Value       interface{} `json:"value"`
	DisplayType string      `json:"display_type,omitempty"`
}

// NFTCollectionInfo represents collection metadata
type NFTCollectionInfo struct {
	Name            string `json:"name"`
	Symbol          string `json:"symbol"`
	MaxSupply       uint64 `json:"max_supply"`
	TotalMinted     uint64 `json:"total_minted"`
	Available       uint64 `json:"available"`
	MintPrice       string `json:"mint_price"`
	Revealed        bool   `json:"revealed"`
	RoyaltyBps      uint16 `json:"royalty_bps"`
	RoyaltyReceiver string `json:"royalty_receiver"`
	ContractAddress string `json:"contract_address"`
}

// MintRequest represents an NFT mint request
type MintRequest struct {
	To       string `json:"to" binding:"required"`
	Quantity uint64 `json:"quantity" binding:"required"`
}

// MintResponse represents an NFT mint response
type MintResponse struct {
	Success       bool        `json:"success"`
	TransactionID string      `json:"transaction_id,omitempty"`
	TokenIDs      []string    `json:"token_ids,omitempty"`
	Tokens        []*NFTToken `json:"tokens,omitempty"`
	Message       string      `json:"message"`
}

// TransferNFTRequest represents an NFT transfer request
type TransferNFTRequest struct {
	From    string `json:"from" binding:"required"`
	To      string `json:"to" binding:"required"`
	TokenID string `json:"token_id" binding:"required"`
}

// TransferNFTResponse represents an NFT transfer response
type TransferNFTResponse struct {
	Success       bool   `json:"success"`
	TransactionID string `json:"transaction_id,omitempty"`
	From          string `json:"from"`
	To            string `json:"to"`
	TokenID       string `json:"token_id"`
	Message       string `json:"message"`
}

// ApproveRequest represents an approval request
type ApproveRequest struct {
	Owner   string `json:"owner" binding:"required"`
	Spender string `json:"spender" binding:"required"`
	TokenID string `json:"token_id" binding:"required"`
}

// SetApprovalForAllRequest represents operator approval request
type SetApprovalForAllRequest struct {
	Owner    string `json:"owner" binding:"required"`
	Operator string `json:"operator" binding:"required"`
	Approved bool   `json:"approved"`
}

// TokenResponse wraps a single token response
type TokenResponse struct {
	Success bool      `json:"success"`
	Token   *NFTToken `json:"token,omitempty"`
	Message string    `json:"message,omitempty"`
}

// TokensListResponse wraps a list of tokens response
type TokensListResponse struct {
	Success  bool        `json:"success"`
	Tokens   []*NFTToken `json:"tokens"`
	Total    int         `json:"total"`
	Page     int         `json:"page"`
	PageSize int         `json:"page_size"`
}

// CollectionInfoResponse wraps collection info response
type CollectionInfoResponse struct {
	Success    bool              `json:"success"`
	Collection NFTCollectionInfo `json:"collection"`
}

// NewNFTHandler creates a new NFT handler
func NewNFTHandler(logger *zap.Logger) *NFTHandler {
	mintPrice, _ := new(big.Int).SetString("100000000000000000", 10) // 0.1 ETH

	h := &NFTHandler{
		logger:            logger,
		tokens:            make(map[string]*NFTToken),
		ownership:         make(map[string][]string),
		approvals:         make(map[string]string),
		operatorApprovals: make(map[string]map[string]bool),
		name:              "Nexus Genesis Collection",
		symbol:            "NXSNFT",
		maxSupply:         10000,
		totalMinted:       0,
		mintPrice:         mintPrice,
		revealed:          true,
		baseURI:           "https://api.nexusprotocol.io/metadata/",
		unrevealedURI:     "https://api.nexusprotocol.io/metadata/unrevealed.json",
		royaltyBps:        500, // 5% royalty
		royaltyReceiver:   "0x0000000000000000000000000000000000000001",
	}

	// Seed demo NFTs
	h.seedDemoNFTs()

	return h
}

// seedDemoNFTs initializes demo NFTs for testing
func (h *NFTHandler) seedDemoNFTs() {
	now := time.Now()
	demoOwner := "0x0000000000000000000000000000000000000003"

	rarities := []string{"Common", "Uncommon", "Rare", "Epic", "Legendary"}
	elements := []string{"Fire", "Water", "Earth", "Air", "Lightning"}

	for i := 1; i <= 5; i++ {
		tokenID := fmt.Sprintf("%d", i)
		token := &NFTToken{
			TokenID:     tokenID,
			Owner:       demoOwner,
			Name:        fmt.Sprintf("Nexus Guardian #%d", i),
			Description: "A powerful guardian from the Nexus realm, sworn to protect the protocol.",
			Image:       fmt.Sprintf("https://api.nexusprotocol.io/images/%d.png", i),
			Attributes: []NFTAttribute{
				{TraitType: "Rarity", Value: rarities[i-1]},
				{TraitType: "Element", Value: elements[i-1]},
				{TraitType: "Power Level", Value: i * 20, DisplayType: "number"},
				{TraitType: "Generation", Value: 1, DisplayType: "number"},
			},
			Soulbound: i == 5, // Last one is soulbound (Legendary)
			MintedAt:  now.Add(-time.Duration(i) * 24 * time.Hour),
		}
		h.tokens[tokenID] = token
		h.ownership[demoOwner] = append(h.ownership[demoOwner], tokenID)
		h.totalMinted++
	}
}

// generateTokenID generates a unique token ID
func (h *NFTHandler) generateTokenID() string {
	h.totalMinted++
	return fmt.Sprintf("%d", h.totalMinted)
}

// GetCollectionInfo handles GET /api/v1/nft/collection
// @Summary Get collection info
// @Description Returns NFT collection metadata
// @Tags nft
// @Produce json
// @Success 200 {object} CollectionInfoResponse
// @Router /api/v1/nft/collection [get]
func (h *NFTHandler) GetCollectionInfo(c *gin.Context) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	c.JSON(http.StatusOK, CollectionInfoResponse{
		Success: true,
		Collection: NFTCollectionInfo{
			Name:            h.name,
			Symbol:          h.symbol,
			MaxSupply:       h.maxSupply,
			TotalMinted:     h.totalMinted,
			Available:       h.maxSupply - h.totalMinted,
			MintPrice:       h.mintPrice.String(),
			Revealed:        h.revealed,
			RoyaltyBps:      h.royaltyBps,
			RoyaltyReceiver: h.royaltyReceiver,
			ContractAddress: "0x...", // Would be actual contract address
		},
	})
}

// Mint handles POST /api/v1/nft/mint
// @Summary Mint NFTs
// @Description Mints new NFTs to the specified address
// @Tags nft
// @Accept json
// @Produce json
// @Param request body MintRequest true "Mint request"
// @Success 200 {object} MintResponse
// @Failure 400 {object} MintResponse
// @Router /api/v1/nft/mint [post]
func (h *NFTHandler) Mint(c *gin.Context) {
	var req MintRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid mint request", zap.Error(err))
		c.JSON(http.StatusBadRequest, MintResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate address
	if !isValidAddress(req.To) {
		c.JSON(http.StatusBadRequest, MintResponse{
			Success: false,
			Message: "Invalid recipient address format",
		})
		return
	}

	// Validate quantity
	if req.Quantity == 0 || req.Quantity > 10 {
		c.JSON(http.StatusBadRequest, MintResponse{
			Success: false,
			Message: "Quantity must be between 1 and 10",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	// Check supply
	if h.totalMinted+req.Quantity > h.maxSupply {
		c.JSON(http.StatusBadRequest, MintResponse{
			Success: false,
			Message: fmt.Sprintf("Not enough supply. Available: %d", h.maxSupply-h.totalMinted),
		})
		return
	}

	to := strings.ToLower(req.To)
	now := time.Now()

	var tokenIDs []string
	var tokens []*NFTToken

	for i := uint64(0); i < req.Quantity; i++ {
		tokenID := h.generateTokenID()

		// Generate random-ish attributes based on token ID
		hash := sha256.Sum256([]byte(tokenID + now.String()))
		hashInt := new(big.Int).SetBytes(hash[:])

		rarityIndex := new(big.Int).Mod(hashInt, big.NewInt(100)).Int64()
		var rarity string
		switch {
		case rarityIndex < 50:
			rarity = "Common"
		case rarityIndex < 75:
			rarity = "Uncommon"
		case rarityIndex < 90:
			rarity = "Rare"
		case rarityIndex < 98:
			rarity = "Epic"
		default:
			rarity = "Legendary"
		}

		elements := []string{"Fire", "Water", "Earth", "Air", "Lightning"}
		elementIndex := new(big.Int).Mod(hashInt, big.NewInt(5)).Int64()

		token := &NFTToken{
			TokenID:     tokenID,
			Owner:       to,
			Name:        fmt.Sprintf("Nexus Guardian #%s", tokenID),
			Description: "A powerful guardian from the Nexus realm, sworn to protect the protocol.",
			Image:       fmt.Sprintf("https://api.nexusprotocol.io/images/%s.png", tokenID),
			Attributes: []NFTAttribute{
				{TraitType: "Rarity", Value: rarity},
				{TraitType: "Element", Value: elements[elementIndex]},
				{TraitType: "Power Level", Value: 10 + (hashInt.Int64() % 90), DisplayType: "number"},
				{TraitType: "Generation", Value: 1, DisplayType: "number"},
			},
			Soulbound: false,
			MintedAt:  now,
		}

		h.tokens[tokenID] = token
		h.ownership[to] = append(h.ownership[to], tokenID)
		tokenIDs = append(tokenIDs, tokenID)
		tokens = append(tokens, token)
	}

	h.logger.Info("NFTs minted",
		zap.String("to", to),
		zap.Uint64("quantity", req.Quantity),
		zap.Strings("token_ids", tokenIDs),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, MintResponse{
		Success:       true,
		TransactionID: txID,
		TokenIDs:      tokenIDs,
		Tokens:        tokens,
		Message:       fmt.Sprintf("Successfully minted %d NFT(s)", req.Quantity),
	})
}

// GetToken handles GET /api/v1/nft/token/:id
// @Summary Get token by ID
// @Description Returns NFT details for the given token ID
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Success 200 {object} TokenResponse
// @Failure 404 {object} TokenResponse
// @Router /api/v1/nft/token/{id} [get]
func (h *NFTHandler) GetToken(c *gin.Context) {
	tokenID := c.Param("id")

	h.mu.RLock()
	token, exists := h.tokens[tokenID]
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, TokenResponse{
			Success: false,
			Message: "Token not found",
		})
		return
	}

	h.logger.Debug("token retrieved",
		zap.String("token_id", tokenID),
		zap.String("owner", token.Owner),
	)

	c.JSON(http.StatusOK, TokenResponse{
		Success: true,
		Token:   token,
	})
}

// GetTokenMetadata handles GET /api/v1/nft/metadata/:id
// @Summary Get token metadata
// @Description Returns ERC-721 compliant metadata for the given token ID
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Success 200 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/metadata/{id} [get]
func (h *NFTHandler) GetTokenMetadata(c *gin.Context) {
	tokenID := c.Param("id")

	h.mu.RLock()
	token, exists := h.tokens[tokenID]
	revealed := h.revealed
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"error": "Token not found",
		})
		return
	}

	// Return unrevealed metadata if not revealed
	if !revealed {
		c.JSON(http.StatusOK, gin.H{
			"name":        "Unrevealed Nexus Guardian",
			"description": "This guardian has not yet been revealed. Stay tuned!",
			"image":       h.unrevealedURI,
			"attributes":  []interface{}{},
		})
		return
	}

	// Return ERC-721 compliant metadata
	c.JSON(http.StatusOK, gin.H{
		"name":        token.Name,
		"description": token.Description,
		"image":       token.Image,
		"external_url": fmt.Sprintf("https://nexusprotocol.io/nft/%s", tokenID),
		"attributes":  token.Attributes,
	})
}

// GetTokensByOwner handles GET /api/v1/nft/owner/:address
// @Summary Get tokens by owner
// @Description Returns all NFTs owned by the given address
// @Tags nft
// @Produce json
// @Param address path string true "Owner address"
// @Param page query int false "Page number (default: 1)"
// @Param page_size query int false "Page size (default: 20, max: 100)"
// @Success 200 {object} TokensListResponse
// @Failure 400 {object} TokensListResponse
// @Router /api/v1/nft/owner/{address} [get]
func (h *NFTHandler) GetTokensByOwner(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, TokensListResponse{
			Success: false,
		})
		return
	}

	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	address = strings.ToLower(address)

	h.mu.RLock()
	tokenIDs := h.ownership[address]
	var tokens []*NFTToken
	for _, tokenID := range tokenIDs {
		if token, exists := h.tokens[tokenID]; exists {
			tokens = append(tokens, token)
		}
	}
	h.mu.RUnlock()

	// Sort by minted_at descending
	sort.Slice(tokens, func(i, j int) bool {
		return tokens[i].MintedAt.After(tokens[j].MintedAt)
	})

	// Paginate
	total := len(tokens)
	start := (page - 1) * pageSize
	end := start + pageSize

	if start >= total {
		c.JSON(http.StatusOK, TokensListResponse{
			Success:  true,
			Tokens:   []*NFTToken{},
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		})
		return
	}

	if end > total {
		end = total
	}

	c.JSON(http.StatusOK, TokensListResponse{
		Success:  true,
		Tokens:   tokens[start:end],
		Total:    total,
		Page:     page,
		PageSize: pageSize,
	})
}

// Transfer handles POST /api/v1/nft/transfer
// @Summary Transfer NFT
// @Description Transfers an NFT from one address to another
// @Tags nft
// @Accept json
// @Produce json
// @Param request body TransferNFTRequest true "Transfer request"
// @Success 200 {object} TransferNFTResponse
// @Failure 400 {object} TransferNFTResponse
// @Failure 403 {object} TransferNFTResponse
// @Failure 404 {object} TransferNFTResponse
// @Router /api/v1/nft/transfer [post]
func (h *NFTHandler) Transfer(c *gin.Context) {
	var req TransferNFTRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid transfer request", zap.Error(err))
		c.JSON(http.StatusBadRequest, TransferNFTResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate addresses
	if !isValidAddress(req.From) {
		c.JSON(http.StatusBadRequest, TransferNFTResponse{
			Success: false,
			Message: "Invalid 'from' address format",
		})
		return
	}

	if !isValidAddress(req.To) {
		c.JSON(http.StatusBadRequest, TransferNFTResponse{
			Success: false,
			Message: "Invalid 'to' address format",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	// Check token exists
	token, exists := h.tokens[req.TokenID]
	if !exists {
		c.JSON(http.StatusNotFound, TransferNFTResponse{
			Success: false,
			Message: "Token not found",
		})
		return
	}

	from := strings.ToLower(req.From)
	to := strings.ToLower(req.To)

	// Check ownership
	if token.Owner != from {
		c.JSON(http.StatusForbidden, TransferNFTResponse{
			Success: false,
			Message: "Address does not own this token",
		})
		return
	}

	// Check if soulbound
	if token.Soulbound {
		c.JSON(http.StatusForbidden, TransferNFTResponse{
			Success: false,
			Message: "This token is soulbound and cannot be transferred",
		})
		return
	}

	// Update ownership
	token.Owner = to
	now := time.Now()
	token.TransferredAt = &now

	// Update ownership mapping
	h.removeTokenFromOwner(from, req.TokenID)
	h.ownership[to] = append(h.ownership[to], req.TokenID)

	// Clear approval
	delete(h.approvals, req.TokenID)

	h.logger.Info("NFT transferred",
		zap.String("token_id", req.TokenID),
		zap.String("from", from),
		zap.String("to", to),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, TransferNFTResponse{
		Success:       true,
		TransactionID: txID,
		From:          from,
		To:            to,
		TokenID:       req.TokenID,
		Message:       "Transfer successful",
	})
}

// removeTokenFromOwner removes a token ID from an owner's list
func (h *NFTHandler) removeTokenFromOwner(owner, tokenID string) {
	tokens := h.ownership[owner]
	for i, id := range tokens {
		if id == tokenID {
			h.ownership[owner] = append(tokens[:i], tokens[i+1:]...)
			break
		}
	}
}

// Approve handles POST /api/v1/nft/approve
// @Summary Approve NFT transfer
// @Description Approves an address to transfer a specific NFT
// @Tags nft
// @Accept json
// @Produce json
// @Param request body ApproveRequest true "Approve request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/approve [post]
func (h *NFTHandler) Approve(c *gin.Context) {
	var req ApproveRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Owner) || !isValidAddress(req.Spender) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	token, exists := h.tokens[req.TokenID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	owner := strings.ToLower(req.Owner)
	spender := strings.ToLower(req.Spender)

	if token.Owner != owner {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Address does not own this token",
		})
		return
	}

	h.approvals[req.TokenID] = spender

	h.logger.Info("NFT approval granted",
		zap.String("token_id", req.TokenID),
		zap.String("owner", owner),
		zap.String("spender", spender),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"transaction_id": txID,
		"token_id":       req.TokenID,
		"owner":          owner,
		"spender":        spender,
		"message":        "Approval granted",
	})
}

// GetApproved handles GET /api/v1/nft/approved/:id
// @Summary Get approved address
// @Description Returns the approved address for a specific NFT
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Success 200 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/approved/{id} [get]
func (h *NFTHandler) GetApproved(c *gin.Context) {
	tokenID := c.Param("id")

	h.mu.RLock()
	token, exists := h.tokens[tokenID]
	approved := h.approvals[tokenID]
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	if approved == "" {
		approved = "0x0000000000000000000000000000000000000000"
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"token_id": tokenID,
		"owner":    token.Owner,
		"approved": approved,
	})
}

// SetApprovalForAll handles POST /api/v1/nft/approval-for-all
// @Summary Set operator approval
// @Description Approves or revokes an operator to manage all NFTs of an owner
// @Tags nft
// @Accept json
// @Produce json
// @Param request body SetApprovalForAllRequest true "Set approval request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/nft/approval-for-all [post]
func (h *NFTHandler) SetApprovalForAll(c *gin.Context) {
	var req SetApprovalForAllRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Owner) || !isValidAddress(req.Operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	owner := strings.ToLower(req.Owner)
	operator := strings.ToLower(req.Operator)

	h.mu.Lock()
	if h.operatorApprovals[owner] == nil {
		h.operatorApprovals[owner] = make(map[string]bool)
	}
	h.operatorApprovals[owner][operator] = req.Approved
	h.mu.Unlock()

	h.logger.Info("operator approval updated",
		zap.String("owner", owner),
		zap.String("operator", operator),
		zap.Bool("approved", req.Approved),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"transaction_id": txID,
		"owner":          owner,
		"operator":       operator,
		"approved":       req.Approved,
		"message":        "Operator approval updated",
	})
}

// IsApprovedForAll handles GET /api/v1/nft/is-approved-for-all/:owner/:operator
// @Summary Check operator approval
// @Description Checks if an operator is approved to manage all NFTs of an owner
// @Tags nft
// @Produce json
// @Param owner path string true "Owner address"
// @Param operator path string true "Operator address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/nft/is-approved-for-all/{owner}/{operator} [get]
func (h *NFTHandler) IsApprovedForAll(c *gin.Context) {
	owner := c.Param("owner")
	operator := c.Param("operator")

	if !isValidAddress(owner) || !isValidAddress(operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	owner = strings.ToLower(owner)
	operator = strings.ToLower(operator)

	h.mu.RLock()
	approved := false
	if h.operatorApprovals[owner] != nil {
		approved = h.operatorApprovals[owner][operator]
	}
	h.mu.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"owner":    owner,
		"operator": operator,
		"approved": approved,
	})
}

// OwnerOf handles GET /api/v1/nft/owner-of/:id
// @Summary Get token owner
// @Description Returns the owner address of a specific NFT
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Success 200 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/owner-of/{id} [get]
func (h *NFTHandler) OwnerOf(c *gin.Context) {
	tokenID := c.Param("id")

	h.mu.RLock()
	token, exists := h.tokens[tokenID]
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":  true,
		"token_id": tokenID,
		"owner":    token.Owner,
	})
}

// BalanceOf handles GET /api/v1/nft/balance/:address
// @Summary Get NFT balance
// @Description Returns the number of NFTs owned by an address
// @Tags nft
// @Produce json
// @Param address path string true "Owner address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/nft/balance/{address} [get]
func (h *NFTHandler) BalanceOf(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)

	h.mu.RLock()
	balance := len(h.ownership[address])
	h.mu.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"balance": balance,
	})
}

// TokenURI handles GET /api/v1/nft/token-uri/:id
// @Summary Get token URI
// @Description Returns the metadata URI for a specific NFT
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Success 200 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/token-uri/{id} [get]
func (h *NFTHandler) TokenURI(c *gin.Context) {
	tokenID := c.Param("id")

	h.mu.RLock()
	_, exists := h.tokens[tokenID]
	revealed := h.revealed
	baseURI := h.baseURI
	unrevealedURI := h.unrevealedURI
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	var tokenURI string
	if revealed {
		tokenURI = baseURI + tokenID + ".json"
	} else {
		tokenURI = unrevealedURI
	}

	c.JSON(http.StatusOK, gin.H{
		"success":   true,
		"token_id":  tokenID,
		"token_uri": tokenURI,
	})
}

// RoyaltyInfo handles GET /api/v1/nft/royalty/:id/:salePrice
// @Summary Get royalty info
// @Description Returns EIP-2981 royalty info for a token sale
// @Tags nft
// @Produce json
// @Param id path string true "Token ID"
// @Param salePrice path string true "Sale price in wei"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/royalty/{id}/{salePrice} [get]
func (h *NFTHandler) RoyaltyInfo(c *gin.Context) {
	tokenID := c.Param("id")
	salePriceStr := c.Param("salePrice")

	h.mu.RLock()
	_, exists := h.tokens[tokenID]
	royaltyBps := h.royaltyBps
	royaltyReceiver := h.royaltyReceiver
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	salePrice, ok := new(big.Int).SetString(salePriceStr, 10)
	if !ok || salePrice.Sign() < 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid sale price",
		})
		return
	}

	// Calculate royalty amount
	royaltyAmount := new(big.Int).Mul(salePrice, big.NewInt(int64(royaltyBps)))
	royaltyAmount.Div(royaltyAmount, big.NewInt(10000))

	c.JSON(http.StatusOK, gin.H{
		"success":          true,
		"token_id":         tokenID,
		"sale_price":       salePriceStr,
		"royalty_receiver": royaltyReceiver,
		"royalty_amount":   royaltyAmount.String(),
		"royalty_bps":      royaltyBps,
	})
}

// TotalSupply handles GET /api/v1/nft/total-supply
// @Summary Get total supply
// @Description Returns the total number of minted NFTs
// @Tags nft
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/nft/total-supply [get]
func (h *NFTHandler) TotalSupply(c *gin.Context) {
	h.mu.RLock()
	totalMinted := h.totalMinted
	maxSupply := h.maxSupply
	h.mu.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"total_supply":  totalMinted,
		"max_supply":    maxSupply,
		"available":     maxSupply - totalMinted,
		"timestamp":     time.Now().UTC().Format(time.RFC3339),
	})
}

// Burn handles POST /api/v1/nft/burn
// @Summary Burn an NFT
// @Description Burns (destroys) an NFT permanently
// @Tags nft
// @Accept json
// @Produce json
// @Param request body map[string]string true "Burn request with owner and token_id"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Failure 404 {object} map[string]interface{}
// @Router /api/v1/nft/burn [post]
func (h *NFTHandler) Burn(c *gin.Context) {
	var req struct {
		Owner   string `json:"owner" binding:"required"`
		TokenID string `json:"token_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Owner) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid owner address format",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	token, exists := h.tokens[req.TokenID]
	if !exists {
		c.JSON(http.StatusNotFound, gin.H{
			"success": false,
			"message": "Token not found",
		})
		return
	}

	owner := strings.ToLower(req.Owner)

	if token.Owner != owner {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Address does not own this token",
		})
		return
	}

	// Remove token
	delete(h.tokens, req.TokenID)
	delete(h.approvals, req.TokenID)
	h.removeTokenFromOwner(owner, req.TokenID)

	h.logger.Info("NFT burned",
		zap.String("token_id", req.TokenID),
		zap.String("owner", owner),
	)

	txID := generateMockTxID()

	// Generate a burn proof hash
	burnData := req.TokenID + owner + time.Now().String()
	burnHash := sha256.Sum256([]byte(burnData))
	burnProof := "0x" + hex.EncodeToString(burnHash[:])

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"transaction_id": txID,
		"token_id":       req.TokenID,
		"burned_by":      owner,
		"burn_proof":     burnProof,
		"message":        "NFT burned successfully",
	})
}
