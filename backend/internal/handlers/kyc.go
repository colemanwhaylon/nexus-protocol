package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// KYCHandler handles KYC-related API endpoints
type KYCHandler struct {
	logger         *zap.Logger
	mu             sync.RWMutex
	registrations  map[string]*KYCRegistration
	whitelist      map[string]bool
	blacklist      map[string]bool
	complianceOfficers map[string]bool
	auditLog       []*AuditLogEntry
	jurisdictions  map[string]*JurisdictionConfig
}

// KYCStatus represents the KYC verification status
type KYCStatus string

const (
	KYCStatusPending   KYCStatus = "pending"
	KYCStatusApproved  KYCStatus = "approved"
	KYCStatusRejected  KYCStatus = "rejected"
	KYCStatusExpired   KYCStatus = "expired"
	KYCStatusSuspended KYCStatus = "suspended"
)

// KYCLevel represents the verification level
type KYCLevel uint8

const (
	KYCLevelNone     KYCLevel = 0
	KYCLevelBasic    KYCLevel = 1 // Email verification
	KYCLevelStandard KYCLevel = 2 // ID verification
	KYCLevelAdvanced KYCLevel = 3 // Full verification with proof of address
)

// KYCRegistration represents a user's KYC registration
type KYCRegistration struct {
	Address           string    `json:"address"`
	Status            KYCStatus `json:"status"`
	Level             KYCLevel  `json:"level"`
	Jurisdiction      string    `json:"jurisdiction"` // ISO 3166-1 alpha-2 country code
	VerifiedAt        *time.Time `json:"verified_at,omitempty"`
	ExpiresAt         *time.Time `json:"expires_at,omitempty"`
	RejectionReason   string    `json:"rejection_reason,omitempty"`
	SuspensionReason  string    `json:"suspension_reason,omitempty"`
	DocumentHash      string    `json:"document_hash,omitempty"` // Hash of submitted documents
	RiskScore         uint8     `json:"risk_score"` // 0-100, higher = more risk
	AccreditedInvestor bool     `json:"accredited_investor"`
	CreatedAt         time.Time `json:"created_at"`
	UpdatedAt         time.Time `json:"updated_at"`
	ReviewedBy        string    `json:"reviewed_by,omitempty"`
}

// JurisdictionConfig represents jurisdiction-specific settings
type JurisdictionConfig struct {
	Code              string   `json:"code"`
	Name              string   `json:"name"`
	Allowed           bool     `json:"allowed"`
	RequiredLevel     KYCLevel `json:"required_level"`
	MaxTransactionUSD uint64   `json:"max_transaction_usd"`
	RequiresAccredited bool    `json:"requires_accredited"`
	Restricted        bool     `json:"restricted"` // OFAC or similar restrictions
}

// AuditLogEntry represents a compliance audit log entry
type AuditLogEntry struct {
	ID            string    `json:"id"`
	Timestamp     time.Time `json:"timestamp"`
	Action        string    `json:"action"`
	Actor         string    `json:"actor"`
	Subject       string    `json:"subject"`
	Details       string    `json:"details"`
	IPAddress     string    `json:"ip_address,omitempty"`
	PreviousState string    `json:"previous_state,omitempty"`
	NewState      string    `json:"new_state,omitempty"`
}

// RegisterKYCRequest represents a KYC registration request
type RegisterKYCRequest struct {
	Address           string `json:"address" binding:"required"`
	Jurisdiction      string `json:"jurisdiction" binding:"required"`
	DocumentHash      string `json:"document_hash,omitempty"`
	AccreditedInvestor bool  `json:"accredited_investor"`
}

// UpdateKYCRequest represents a KYC update request
type UpdateKYCRequest struct {
	Address          string    `json:"address" binding:"required"`
	Status           KYCStatus `json:"status" binding:"required"`
	Level            KYCLevel  `json:"level,omitempty"`
	RejectionReason  string    `json:"rejection_reason,omitempty"`
	SuspensionReason string    `json:"suspension_reason,omitempty"`
	Reviewer         string    `json:"reviewer" binding:"required"`
}

// WhitelistRequest represents a whitelist/blacklist update request
type WhitelistRequest struct {
	Address  string `json:"address" binding:"required"`
	Operator string `json:"operator" binding:"required"`
	Reason   string `json:"reason,omitempty"`
}

// KYCResponse wraps a KYC registration response
type KYCResponse struct {
	Success      bool             `json:"success"`
	Registration *KYCRegistration `json:"registration,omitempty"`
	Message      string           `json:"message,omitempty"`
}

// KYCListResponse wraps a list of KYC registrations
type KYCListResponse struct {
	Success       bool               `json:"success"`
	Registrations []*KYCRegistration `json:"registrations"`
	Total         int                `json:"total"`
	Page          int                `json:"page"`
	PageSize      int                `json:"page_size"`
}

// AuditLogResponse wraps audit log entries
type AuditLogResponse struct {
	Success bool             `json:"success"`
	Entries []*AuditLogEntry `json:"entries"`
	Total   int              `json:"total"`
	Page    int              `json:"page"`
	PageSize int             `json:"page_size"`
}

// ComplianceCheckResponse represents a compliance check result
type ComplianceCheckResponse struct {
	Success         bool     `json:"success"`
	Address         string   `json:"address"`
	IsCompliant     bool     `json:"is_compliant"`
	KYCStatus       KYCStatus `json:"kyc_status"`
	KYCLevel        KYCLevel `json:"kyc_level"`
	IsWhitelisted   bool     `json:"is_whitelisted"`
	IsBlacklisted   bool     `json:"is_blacklisted"`
	Jurisdiction    string   `json:"jurisdiction,omitempty"`
	CanTransact     bool     `json:"can_transact"`
	MaxTransaction  string   `json:"max_transaction,omitempty"`
	Restrictions    []string `json:"restrictions,omitempty"`
	Message         string   `json:"message,omitempty"`
}

// NewKYCHandler creates a new KYC handler
func NewKYCHandler(logger *zap.Logger) *KYCHandler {
	h := &KYCHandler{
		logger:             logger,
		registrations:      make(map[string]*KYCRegistration),
		whitelist:          make(map[string]bool),
		blacklist:          make(map[string]bool),
		complianceOfficers: make(map[string]bool),
		auditLog:           make([]*AuditLogEntry, 0),
		jurisdictions:      make(map[string]*JurisdictionConfig),
	}

	// Initialize jurisdictions
	h.initializeJurisdictions()

	// Add demo compliance officers
	h.complianceOfficers["0x0000000000000000000000000000000000000001"] = true
	h.complianceOfficers["0x0000000000000000000000000000000000000002"] = true

	// Seed demo KYC data
	h.seedDemoKYC()

	return h
}

// initializeJurisdictions sets up jurisdiction configurations
func (h *KYCHandler) initializeJurisdictions() {
	// Major jurisdictions - simplified for demo
	jurisdictions := []JurisdictionConfig{
		{Code: "US", Name: "United States", Allowed: true, RequiredLevel: KYCLevelAdvanced, MaxTransactionUSD: 0, RequiresAccredited: true, Restricted: false},
		{Code: "GB", Name: "United Kingdom", Allowed: true, RequiredLevel: KYCLevelStandard, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		{Code: "DE", Name: "Germany", Allowed: true, RequiredLevel: KYCLevelStandard, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		{Code: "SG", Name: "Singapore", Allowed: true, RequiredLevel: KYCLevelStandard, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		{Code: "JP", Name: "Japan", Allowed: true, RequiredLevel: KYCLevelAdvanced, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		{Code: "CH", Name: "Switzerland", Allowed: true, RequiredLevel: KYCLevelBasic, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		{Code: "AE", Name: "United Arab Emirates", Allowed: true, RequiredLevel: KYCLevelStandard, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: false},
		// Restricted jurisdictions (OFAC sanctioned)
		{Code: "KP", Name: "North Korea", Allowed: false, RequiredLevel: KYCLevelNone, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: true},
		{Code: "IR", Name: "Iran", Allowed: false, RequiredLevel: KYCLevelNone, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: true},
		{Code: "CU", Name: "Cuba", Allowed: false, RequiredLevel: KYCLevelNone, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: true},
		{Code: "SY", Name: "Syria", Allowed: false, RequiredLevel: KYCLevelNone, MaxTransactionUSD: 0, RequiresAccredited: false, Restricted: true},
	}

	for _, j := range jurisdictions {
		h.jurisdictions[j.Code] = &JurisdictionConfig{
			Code:              j.Code,
			Name:              j.Name,
			Allowed:           j.Allowed,
			RequiredLevel:     j.RequiredLevel,
			MaxTransactionUSD: j.MaxTransactionUSD,
			RequiresAccredited: j.RequiresAccredited,
			Restricted:        j.Restricted,
		}
	}
}

// seedDemoKYC initializes demo KYC registrations
func (h *KYCHandler) seedDemoKYC() {
	now := time.Now()
	expiry := now.Add(365 * 24 * time.Hour) // 1 year expiry

	// Approved user
	approvedUser := &KYCRegistration{
		Address:           "0x0000000000000000000000000000000000000003",
		Status:            KYCStatusApproved,
		Level:             KYCLevelAdvanced,
		Jurisdiction:      "US",
		VerifiedAt:        &now,
		ExpiresAt:         &expiry,
		DocumentHash:      "0x" + strings.Repeat("a", 64),
		RiskScore:         15,
		AccreditedInvestor: true,
		CreatedAt:         now.Add(-30 * 24 * time.Hour),
		UpdatedAt:         now,
		ReviewedBy:        "0x0000000000000000000000000000000000000001",
	}
	h.registrations[approvedUser.Address] = approvedUser
	h.whitelist[approvedUser.Address] = true

	// Pending user
	pendingUser := &KYCRegistration{
		Address:           "0x0000000000000000000000000000000000000004",
		Status:            KYCStatusPending,
		Level:             KYCLevelNone,
		Jurisdiction:      "GB",
		DocumentHash:      "0x" + strings.Repeat("b", 64),
		RiskScore:         0,
		AccreditedInvestor: false,
		CreatedAt:         now.Add(-2 * 24 * time.Hour),
		UpdatedAt:         now.Add(-2 * 24 * time.Hour),
	}
	h.registrations[pendingUser.Address] = pendingUser

	// Log seed actions
	h.addAuditLog("SEED_DATA", "system", "system", "Demo KYC data initialized", "", "", "")
}

// generateAuditID generates a unique audit log ID
func (h *KYCHandler) generateAuditID() string {
	data := time.Now().String() + strconv.Itoa(len(h.auditLog))
	hash := sha256.Sum256([]byte(data))
	return "audit-" + hex.EncodeToString(hash[:8])
}

// addAuditLog adds an entry to the audit log
func (h *KYCHandler) addAuditLog(action, actor, subject, details, ip, prevState, newState string) {
	entry := &AuditLogEntry{
		ID:            h.generateAuditID(),
		Timestamp:     time.Now(),
		Action:        action,
		Actor:         actor,
		Subject:       subject,
		Details:       details,
		IPAddress:     ip,
		PreviousState: prevState,
		NewState:      newState,
	}
	h.auditLog = append(h.auditLog, entry)
}

// Register handles POST /api/v1/kyc/register
// @Summary Register for KYC
// @Description Submits a KYC registration request
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body RegisterKYCRequest true "KYC registration request"
// @Success 200 {object} KYCResponse
// @Failure 400 {object} KYCResponse
// @Router /api/v1/kyc/register [post]
func (h *KYCHandler) Register(c *gin.Context) {
	var req RegisterKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid KYC registration request", zap.Error(err))
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate address
	if !isValidAddress(req.Address) {
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid address format",
		})
		return
	}

	// Validate jurisdiction
	req.Jurisdiction = strings.ToUpper(req.Jurisdiction)
	jurisdiction, exists := h.jurisdictions[req.Jurisdiction]
	if !exists {
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid or unsupported jurisdiction code",
		})
		return
	}

	if jurisdiction.Restricted {
		c.JSON(http.StatusForbidden, KYCResponse{
			Success: false,
			Message: "Registration not available for restricted jurisdictions",
		})
		return
	}

	address := strings.ToLower(req.Address)

	h.mu.Lock()
	defer h.mu.Unlock()

	// Check if already registered
	if existing, exists := h.registrations[address]; exists {
		if existing.Status == KYCStatusPending || existing.Status == KYCStatusApproved {
			c.JSON(http.StatusBadRequest, KYCResponse{
				Success: false,
				Message: "Address already has a KYC registration",
			})
			return
		}
	}

	// Check blacklist
	if h.blacklist[address] {
		c.JSON(http.StatusForbidden, KYCResponse{
			Success: false,
			Message: "Address is blacklisted and cannot register",
		})
		return
	}

	now := time.Now()
	registration := &KYCRegistration{
		Address:           address,
		Status:            KYCStatusPending,
		Level:             KYCLevelNone,
		Jurisdiction:      req.Jurisdiction,
		DocumentHash:      req.DocumentHash,
		RiskScore:         0,
		AccreditedInvestor: req.AccreditedInvestor,
		CreatedAt:         now,
		UpdatedAt:         now,
	}

	h.registrations[address] = registration
	h.addAuditLog("KYC_REGISTER", address, address, "New KYC registration submitted", c.ClientIP(), "", string(KYCStatusPending))

	h.logger.Info("KYC registration submitted",
		zap.String("address", address),
		zap.String("jurisdiction", req.Jurisdiction),
	)

	c.JSON(http.StatusOK, KYCResponse{
		Success:      true,
		Registration: registration,
		Message:      "KYC registration submitted successfully. Please await verification.",
	})
}

// GetKYCStatus handles GET /api/v1/kyc/status/:address
// @Summary Get KYC status
// @Description Returns the KYC status for an address
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} KYCResponse
// @Failure 400 {object} KYCResponse
// @Failure 404 {object} KYCResponse
// @Router /api/v1/kyc/status/{address} [get]
func (h *KYCHandler) GetKYCStatus(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)

	h.mu.RLock()
	registration, exists := h.registrations[address]
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, KYCResponse{
			Success: false,
			Message: "No KYC registration found for this address",
		})
		return
	}

	// Check expiration
	if registration.ExpiresAt != nil && time.Now().After(*registration.ExpiresAt) {
		registration.Status = KYCStatusExpired
	}

	h.logger.Debug("KYC status retrieved",
		zap.String("address", address),
		zap.String("status", string(registration.Status)),
	)

	c.JSON(http.StatusOK, KYCResponse{
		Success:      true,
		Registration: registration,
	})
}

// UpdateKYC handles POST /api/v1/kyc/update
// @Summary Update KYC status
// @Description Updates KYC status (compliance officer only)
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body UpdateKYCRequest true "KYC update request"
// @Success 200 {object} KYCResponse
// @Failure 400 {object} KYCResponse
// @Failure 403 {object} KYCResponse
// @Failure 404 {object} KYCResponse
// @Router /api/v1/kyc/update [post]
func (h *KYCHandler) UpdateKYC(c *gin.Context) {
	var req UpdateKYCRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid KYC update request", zap.Error(err))
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate addresses
	if !isValidAddress(req.Address) || !isValidAddress(req.Reviewer) {
		c.JSON(http.StatusBadRequest, KYCResponse{
			Success: false,
			Message: "Invalid address format",
		})
		return
	}

	address := strings.ToLower(req.Address)
	reviewer := strings.ToLower(req.Reviewer)

	h.mu.Lock()
	defer h.mu.Unlock()

	// Check if reviewer is a compliance officer
	if !h.complianceOfficers[reviewer] {
		c.JSON(http.StatusForbidden, KYCResponse{
			Success: false,
			Message: "Only compliance officers can update KYC status",
		})
		return
	}

	registration, exists := h.registrations[address]
	if !exists {
		c.JSON(http.StatusNotFound, KYCResponse{
			Success: false,
			Message: "No KYC registration found for this address",
		})
		return
	}

	prevStatus := registration.Status
	now := time.Now()

	// Update registration
	registration.Status = req.Status
	registration.UpdatedAt = now
	registration.ReviewedBy = reviewer

	if req.Level > 0 {
		registration.Level = req.Level
	}

	switch req.Status {
	case KYCStatusApproved:
		registration.VerifiedAt = &now
		expiry := now.Add(365 * 24 * time.Hour) // 1 year validity
		registration.ExpiresAt = &expiry
		// Auto-whitelist on approval
		h.whitelist[address] = true
	case KYCStatusRejected:
		registration.RejectionReason = req.RejectionReason
	case KYCStatusSuspended:
		registration.SuspensionReason = req.SuspensionReason
		// Remove from whitelist on suspension
		delete(h.whitelist, address)
	}

	h.addAuditLog("KYC_UPDATE", reviewer, address,
		"KYC status updated: "+req.RejectionReason+req.SuspensionReason,
		c.ClientIP(), string(prevStatus), string(req.Status))

	h.logger.Info("KYC status updated",
		zap.String("address", address),
		zap.String("reviewer", reviewer),
		zap.String("old_status", string(prevStatus)),
		zap.String("new_status", string(req.Status)),
	)

	c.JSON(http.StatusOK, KYCResponse{
		Success:      true,
		Registration: registration,
		Message:      "KYC status updated successfully",
	})
}

// AddToWhitelist handles POST /api/v1/kyc/whitelist
// @Summary Add to whitelist
// @Description Adds an address to the whitelist
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body WhitelistRequest true "Whitelist request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/v1/kyc/whitelist [post]
func (h *KYCHandler) AddToWhitelist(c *gin.Context) {
	var req WhitelistRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Address) || !isValidAddress(req.Operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address := strings.ToLower(req.Address)
	operator := strings.ToLower(req.Operator)

	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.complianceOfficers[operator] {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only compliance officers can modify whitelist",
		})
		return
	}

	if h.blacklist[address] {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Cannot whitelist a blacklisted address. Remove from blacklist first.",
		})
		return
	}

	h.whitelist[address] = true
	h.addAuditLog("WHITELIST_ADD", operator, address, "Added to whitelist: "+req.Reason, c.ClientIP(), "", "")

	h.logger.Info("address added to whitelist",
		zap.String("address", address),
		zap.String("operator", operator),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"whitelisted": true,
		"message": "Address added to whitelist",
	})
}

// RemoveFromWhitelist handles DELETE /api/v1/kyc/whitelist/:address
// @Summary Remove from whitelist
// @Description Removes an address from the whitelist
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Param operator query string true "Operator address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/v1/kyc/whitelist/{address} [delete]
func (h *KYCHandler) RemoveFromWhitelist(c *gin.Context) {
	address := c.Param("address")
	operator := c.Query("operator")

	if !isValidAddress(address) || !isValidAddress(operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)
	operator = strings.ToLower(operator)

	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.complianceOfficers[operator] {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only compliance officers can modify whitelist",
		})
		return
	}

	delete(h.whitelist, address)
	h.addAuditLog("WHITELIST_REMOVE", operator, address, "Removed from whitelist", c.ClientIP(), "", "")

	h.logger.Info("address removed from whitelist",
		zap.String("address", address),
		zap.String("operator", operator),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"whitelisted": false,
		"message": "Address removed from whitelist",
	})
}

// AddToBlacklist handles POST /api/v1/kyc/blacklist
// @Summary Add to blacklist
// @Description Adds an address to the blacklist
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body WhitelistRequest true "Blacklist request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/v1/kyc/blacklist [post]
func (h *KYCHandler) AddToBlacklist(c *gin.Context) {
	var req WhitelistRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Address) || !isValidAddress(req.Operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address := strings.ToLower(req.Address)
	operator := strings.ToLower(req.Operator)

	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.complianceOfficers[operator] {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only compliance officers can modify blacklist",
		})
		return
	}

	// Remove from whitelist if present
	delete(h.whitelist, address)
	h.blacklist[address] = true

	// Suspend KYC if exists
	if reg, exists := h.registrations[address]; exists {
		reg.Status = KYCStatusSuspended
		reg.SuspensionReason = "Blacklisted: " + req.Reason
		reg.UpdatedAt = time.Now()
	}

	h.addAuditLog("BLACKLIST_ADD", operator, address, "Added to blacklist: "+req.Reason, c.ClientIP(), "", "")

	h.logger.Warn("address added to blacklist",
		zap.String("address", address),
		zap.String("operator", operator),
		zap.String("reason", req.Reason),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"blacklisted": true,
		"message": "Address added to blacklist",
	})
}

// RemoveFromBlacklist handles DELETE /api/v1/kyc/blacklist/:address
// @Summary Remove from blacklist
// @Description Removes an address from the blacklist
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Param operator query string true "Operator address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/v1/kyc/blacklist/{address} [delete]
func (h *KYCHandler) RemoveFromBlacklist(c *gin.Context) {
	address := c.Param("address")
	operator := c.Query("operator")

	if !isValidAddress(address) || !isValidAddress(operator) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)
	operator = strings.ToLower(operator)

	h.mu.Lock()
	defer h.mu.Unlock()

	if !h.complianceOfficers[operator] {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only compliance officers can modify blacklist",
		})
		return
	}

	delete(h.blacklist, address)
	h.addAuditLog("BLACKLIST_REMOVE", operator, address, "Removed from blacklist", c.ClientIP(), "", "")

	h.logger.Info("address removed from blacklist",
		zap.String("address", address),
		zap.String("operator", operator),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"blacklisted": false,
		"message": "Address removed from blacklist",
	})
}

// CheckCompliance handles GET /api/v1/kyc/check/:address
// @Summary Check compliance status
// @Description Performs a comprehensive compliance check for an address
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} ComplianceCheckResponse
// @Failure 400 {object} ComplianceCheckResponse
// @Router /api/v1/kyc/check/{address} [get]
func (h *KYCHandler) CheckCompliance(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, ComplianceCheckResponse{
			Success: false,
			Address: address,
			Message: "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)

	h.mu.RLock()
	defer h.mu.RUnlock()

	response := ComplianceCheckResponse{
		Success:       true,
		Address:       address,
		IsWhitelisted: h.whitelist[address],
		IsBlacklisted: h.blacklist[address],
	}

	// Check blacklist first
	if response.IsBlacklisted {
		response.IsCompliant = false
		response.CanTransact = false
		response.Restrictions = append(response.Restrictions, "Address is blacklisted")
		response.Message = "Address is blacklisted and cannot transact"
		c.JSON(http.StatusOK, response)
		return
	}

	// Check KYC registration
	registration, hasKYC := h.registrations[address]
	if hasKYC {
		response.KYCStatus = registration.Status
		response.KYCLevel = registration.Level
		response.Jurisdiction = registration.Jurisdiction

		// Check expiration
		if registration.ExpiresAt != nil && time.Now().After(*registration.ExpiresAt) {
			response.KYCStatus = KYCStatusExpired
			response.Restrictions = append(response.Restrictions, "KYC verification has expired")
		}

		// Check jurisdiction
		if j, exists := h.jurisdictions[registration.Jurisdiction]; exists {
			if !j.Allowed {
				response.Restrictions = append(response.Restrictions, "Jurisdiction not allowed")
			}
			if j.RequiresAccredited && !registration.AccreditedInvestor {
				response.Restrictions = append(response.Restrictions, "Accredited investor status required")
			}
			if j.MaxTransactionUSD > 0 {
				response.MaxTransaction = strconv.FormatUint(j.MaxTransactionUSD, 10)
			}
		}
	} else {
		response.KYCStatus = KYCStatusPending
		response.Restrictions = append(response.Restrictions, "No KYC registration found")
	}

	// Determine overall compliance
	response.IsCompliant = response.KYCStatus == KYCStatusApproved &&
		!response.IsBlacklisted &&
		len(response.Restrictions) == 0

	response.CanTransact = response.IsWhitelisted || response.IsCompliant

	if response.IsCompliant {
		response.Message = "Address is fully compliant"
	} else if response.CanTransact {
		response.Message = "Address can transact but has restrictions"
	} else {
		response.Message = "Address is not compliant for transactions"
	}

	c.JSON(http.StatusOK, response)
}

// IsWhitelisted handles GET /api/v1/kyc/is-whitelisted/:address
// @Summary Check whitelist status
// @Description Checks if an address is whitelisted
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/kyc/is-whitelisted/{address} [get]
func (h *KYCHandler) IsWhitelisted(c *gin.Context) {
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
	isWhitelisted := h.whitelist[address]
	h.mu.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"address":     address,
		"whitelisted": isWhitelisted,
	})
}

// IsBlacklisted handles GET /api/v1/kyc/is-blacklisted/:address
// @Summary Check blacklist status
// @Description Checks if an address is blacklisted
// @Tags kyc
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/kyc/is-blacklisted/{address} [get]
func (h *KYCHandler) IsBlacklisted(c *gin.Context) {
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
	isBlacklisted := h.blacklist[address]
	h.mu.RUnlock()

	c.JSON(http.StatusOK, gin.H{
		"success":     true,
		"address":     address,
		"blacklisted": isBlacklisted,
	})
}

// ListPending handles GET /api/v1/kyc/pending
// @Summary List pending KYC registrations
// @Description Returns all pending KYC registrations (compliance officer only)
// @Tags kyc
// @Produce json
// @Param page query int false "Page number (default: 1)"
// @Param page_size query int false "Page size (default: 20, max: 100)"
// @Success 200 {object} KYCListResponse
// @Router /api/v1/kyc/pending [get]
func (h *KYCHandler) ListPending(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "20"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 20
	}

	h.mu.RLock()
	var pending []*KYCRegistration
	for _, reg := range h.registrations {
		if reg.Status == KYCStatusPending {
			pending = append(pending, reg)
		}
	}
	h.mu.RUnlock()

	// Sort by created_at ascending (oldest first)
	sort.Slice(pending, func(i, j int) bool {
		return pending[i].CreatedAt.Before(pending[j].CreatedAt)
	})

	// Paginate
	total := len(pending)
	start := (page - 1) * pageSize
	end := start + pageSize

	if start >= total {
		c.JSON(http.StatusOK, KYCListResponse{
			Success:       true,
			Registrations: []*KYCRegistration{},
			Total:         total,
			Page:          page,
			PageSize:      pageSize,
		})
		return
	}

	if end > total {
		end = total
	}

	c.JSON(http.StatusOK, KYCListResponse{
		Success:       true,
		Registrations: pending[start:end],
		Total:         total,
		Page:          page,
		PageSize:      pageSize,
	})
}

// GetAuditLog handles GET /api/v1/kyc/audit-log
// @Summary Get audit log
// @Description Returns compliance audit log entries
// @Tags kyc
// @Produce json
// @Param page query int false "Page number (default: 1)"
// @Param page_size query int false "Page size (default: 50, max: 100)"
// @Param subject query string false "Filter by subject address"
// @Success 200 {object} AuditLogResponse
// @Router /api/v1/kyc/audit-log [get]
func (h *KYCHandler) GetAuditLog(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "50"))
	subjectFilter := strings.ToLower(c.Query("subject"))

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 50
	}

	h.mu.RLock()
	var entries []*AuditLogEntry
	for _, entry := range h.auditLog {
		if subjectFilter == "" || entry.Subject == subjectFilter {
			entries = append(entries, entry)
		}
	}
	h.mu.RUnlock()

	// Sort by timestamp descending (newest first)
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Timestamp.After(entries[j].Timestamp)
	})

	// Paginate
	total := len(entries)
	start := (page - 1) * pageSize
	end := start + pageSize

	if start >= total {
		c.JSON(http.StatusOK, AuditLogResponse{
			Success:  true,
			Entries:  []*AuditLogEntry{},
			Total:    total,
			Page:     page,
			PageSize: pageSize,
		})
		return
	}

	if end > total {
		end = total
	}

	c.JSON(http.StatusOK, AuditLogResponse{
		Success:  true,
		Entries:  entries[start:end],
		Total:    total,
		Page:     page,
		PageSize: pageSize,
	})
}

// GetJurisdictions handles GET /api/v1/kyc/jurisdictions
// @Summary Get supported jurisdictions
// @Description Returns list of supported jurisdictions and their requirements
// @Tags kyc
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/kyc/jurisdictions [get]
func (h *KYCHandler) GetJurisdictions(c *gin.Context) {
	h.mu.RLock()
	jurisdictions := make([]*JurisdictionConfig, 0, len(h.jurisdictions))
	for _, j := range h.jurisdictions {
		jurisdictions = append(jurisdictions, j)
	}
	h.mu.RUnlock()

	// Sort by code
	sort.Slice(jurisdictions, func(i, j int) bool {
		return jurisdictions[i].Code < jurisdictions[j].Code
	})

	c.JSON(http.StatusOK, gin.H{
		"success":       true,
		"jurisdictions": jurisdictions,
		"total":         len(jurisdictions),
	})
}

// AddComplianceOfficer handles POST /api/v1/kyc/compliance-officer
// @Summary Add compliance officer
// @Description Adds a new compliance officer (admin only)
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body map[string]string true "Add officer request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/kyc/compliance-officer [post]
func (h *KYCHandler) AddComplianceOfficer(c *gin.Context) {
	var req struct {
		Address string `json:"address" binding:"required"`
		Admin   string `json:"admin" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Address) || !isValidAddress(req.Admin) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address := strings.ToLower(req.Address)
	admin := strings.ToLower(req.Admin)

	h.mu.Lock()
	defer h.mu.Unlock()

	// For demo, admin must be first compliance officer
	if admin != "0x0000000000000000000000000000000000000001" {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only admin can add compliance officers",
		})
		return
	}

	h.complianceOfficers[address] = true
	h.addAuditLog("OFFICER_ADD", admin, address, "Compliance officer added", c.ClientIP(), "", "")

	h.logger.Info("compliance officer added",
		zap.String("address", address),
		zap.String("admin", admin),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"role":    "compliance_officer",
		"message": "Compliance officer added successfully",
	})
}

// RemoveComplianceOfficer handles DELETE /api/v1/kyc/compliance-officer/:address
// @Summary Remove compliance officer
// @Description Removes a compliance officer (admin only)
// @Tags kyc
// @Produce json
// @Param address path string true "Officer address"
// @Param admin query string true "Admin address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Failure 403 {object} map[string]interface{}
// @Router /api/v1/kyc/compliance-officer/{address} [delete]
func (h *KYCHandler) RemoveComplianceOfficer(c *gin.Context) {
	address := c.Param("address")
	admin := c.Query("admin")

	if !isValidAddress(address) || !isValidAddress(admin) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	address = strings.ToLower(address)
	admin = strings.ToLower(admin)

	h.mu.Lock()
	defer h.mu.Unlock()

	if admin != "0x0000000000000000000000000000000000000001" {
		c.JSON(http.StatusForbidden, gin.H{
			"success": false,
			"message": "Only admin can remove compliance officers",
		})
		return
	}

	delete(h.complianceOfficers, address)
	h.addAuditLog("OFFICER_REMOVE", admin, address, "Compliance officer removed", c.ClientIP(), "", "")

	h.logger.Info("compliance officer removed",
		zap.String("address", address),
		zap.String("admin", admin),
	)

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"address": address,
		"message": "Compliance officer removed successfully",
	})
}
