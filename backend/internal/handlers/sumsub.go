package handlers

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// SumsubHandler handles Sumsub KYC verification endpoints
type SumsubHandler struct {
	paymentRepo   repository.PaymentRepository
	pricingRepo   repository.PricingRepository
	logger        *zap.Logger
	appToken      string
	secretKey     string
	webhookSecret string
	baseURL       string
}

// NewSumsubHandler creates a new Sumsub handler with injected dependencies
func NewSumsubHandler(
	paymentRepo repository.PaymentRepository,
	pricingRepo repository.PricingRepository,
	logger *zap.Logger,
) *SumsubHandler {
	return &SumsubHandler{
		paymentRepo:   paymentRepo,
		pricingRepo:   pricingRepo,
		logger:        logger,
		appToken:      os.Getenv("SUMSUB_APP_TOKEN"),
		secretKey:     os.Getenv("SUMSUB_SECRET_KEY"),
		webhookSecret: os.Getenv("SUMSUB_WEBHOOK_SECRET"),
		baseURL:       "https://api.sumsub.com",
	}
}

// SumsubResponse wraps Sumsub API responses
type SumsubResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// CreateApplicantRequest represents a request to create a Sumsub applicant
type CreateApplicantRequest struct {
	UserAddress string `json:"user_address" binding:"required"`
	PaymentID   string `json:"payment_id" binding:"required"`
}

// StartVerificationRequest represents a request to start verification
type StartVerificationRequest struct {
	UserAddress string `json:"user_address" binding:"required"`
}

// SumsubApplicant represents a Sumsub applicant
type SumsubApplicant struct {
	ID          string `json:"id"`
	ExternalID  string `json:"externalUserId"`
	Inspection  *struct {
		ID string `json:"id"`
	} `json:"inspection,omitempty"`
}

// SumsubAccessToken represents a Sumsub access token response
type SumsubAccessToken struct {
	Token  string `json:"token"`
	UserID string `json:"userId"`
}

// SumsubWebhookPayload represents the Sumsub webhook payload
type SumsubWebhookPayload struct {
	ApplicantID    string `json:"applicantId"`
	InspectionID   string `json:"inspectionId"`
	CorrelationID  string `json:"correlationId"`
	ExternalUserID string `json:"externalUserId"`
	Type           string `json:"type"`
	ReviewStatus   string `json:"reviewStatus"`
	ReviewResult   *struct {
		ReviewAnswer     string `json:"reviewAnswer"`
		RejectLabels     []string `json:"rejectLabels,omitempty"`
		ReviewRejectType string `json:"reviewRejectType,omitempty"`
	} `json:"reviewResult,omitempty"`
	CreatedAt time.Time `json:"createdAt"`
}

// CreateApplicant handles POST /api/v1/kyc/sumsub/applicant
// @Summary Create Sumsub applicant
// @Description Creates a new applicant in Sumsub for KYC verification
// @Tags kyc
// @Accept json
// @Produce json
// @Param request body CreateApplicantRequest true "Applicant request"
// @Success 200 {object} SumsubResponse
// @Failure 400 {object} SumsubResponse
// @Router /api/v1/kyc/sumsub/applicant [post]
func (h *SumsubHandler) CreateApplicant(c *gin.Context) {
	var req CreateApplicantRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.UserAddress) {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Invalid user address format",
		})
		return
	}

	ctx := c.Request.Context()
	userAddress := strings.ToLower(req.UserAddress)

	// Verify payment exists and is completed
	payment, err := h.paymentRepo.GetPayment(ctx, req.PaymentID)
	if err != nil {
		if errors.Is(err, repository.ErrPaymentNotFound) {
			c.JSON(http.StatusBadRequest, SumsubResponse{
				Success: false,
				Error:   "Payment not found",
			})
			return
		}
		h.logger.Error("failed to get payment", zap.Error(err))
		c.JSON(http.StatusInternalServerError, SumsubResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	if payment.Status != repository.PaymentStatusCompleted {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Payment not completed",
		})
		return
	}

	if strings.ToLower(payment.PayerAddress) != userAddress {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Payment address does not match",
		})
		return
	}

	// Create applicant in Sumsub
	applicant, err := h.createSumsubApplicant(userAddress)
	if err != nil {
		h.logger.Error("failed to create Sumsub applicant", zap.Error(err))
		c.JSON(http.StatusInternalServerError, SumsubResponse{
			Success: false,
			Error:   "Failed to create verification applicant",
		})
		return
	}

	// Create or update KYC verification record
	verification := &repository.KYCVerification{
		PaymentID:         &req.PaymentID,
		UserAddress:       userAddress,
		SumsubApplicantID: &applicant.ID,
		Status:            repository.KYCStatusSubmitted,
	}

	// Check if verification already exists
	existing, _ := h.paymentRepo.GetKYCVerificationByAddress(ctx, userAddress)
	if existing != nil {
		// Update existing
		update := &repository.KYCVerificationUpdate{
			SumsubApplicantID: &applicant.ID,
		}
		status := repository.KYCStatusSubmitted
		update.Status = &status
		if err := h.paymentRepo.UpdateKYCVerification(ctx, existing.ID, update); err != nil {
			h.logger.Error("failed to update KYC verification", zap.Error(err))
		}
	} else {
		// Create new
		if err := h.paymentRepo.CreateKYCVerification(ctx, verification); err != nil {
			h.logger.Error("failed to create KYC verification", zap.Error(err))
		}
	}

	h.logger.Info("Sumsub applicant created",
		zap.String("applicant_id", applicant.ID),
		zap.String("user_address", userAddress),
	)

	c.JSON(http.StatusOK, SumsubResponse{
		Success: true,
		Data: gin.H{
			"applicant_id":   applicant.ID,
			"external_id":    applicant.ExternalID,
		},
	})
}

// GetAccessToken handles GET /api/v1/kyc/sumsub/token/:address
// @Summary Get Sumsub access token
// @Description Gets an access token for the Sumsub WebSDK
// @Tags kyc
// @Produce json
// @Param address path string true "User address"
// @Success 200 {object} SumsubResponse
// @Failure 400 {object} SumsubResponse
// @Router /api/v1/kyc/sumsub/token/{address} [get]
func (h *SumsubHandler) GetAccessToken(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Invalid address format",
		})
		return
	}

	userAddress := strings.ToLower(address)
	ctx := c.Request.Context()

	// Get existing verification to get applicant ID
	verification, err := h.paymentRepo.GetKYCVerificationByAddress(ctx, userAddress)
	if err != nil {
		if errors.Is(err, repository.ErrKYCNotFound) {
			c.JSON(http.StatusBadRequest, SumsubResponse{
				Success: false,
				Error:   "No verification found for address. Complete payment first.",
			})
			return
		}
		h.logger.Error("failed to get verification", zap.Error(err))
		c.JSON(http.StatusInternalServerError, SumsubResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	if verification.SumsubApplicantID == nil {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Applicant not created. Call create applicant first.",
		})
		return
	}

	// Get access token from Sumsub
	token, err := h.getSumsubAccessToken(userAddress)
	if err != nil {
		h.logger.Error("failed to get Sumsub access token", zap.Error(err))
		c.JSON(http.StatusInternalServerError, SumsubResponse{
			Success: false,
			Error:   "Failed to get verification token",
		})
		return
	}

	c.JSON(http.StatusOK, SumsubResponse{
		Success: true,
		Data: gin.H{
			"token":        token.Token,
			"applicant_id": verification.SumsubApplicantID,
		},
	})
}

// GetVerificationStatus handles GET /api/v1/kyc/sumsub/status/:address
// @Summary Get KYC verification status
// @Description Returns the current verification status for an address
// @Tags kyc
// @Produce json
// @Param address path string true "User address"
// @Success 200 {object} SumsubResponse
// @Failure 404 {object} SumsubResponse
// @Router /api/v1/kyc/sumsub/status/{address} [get]
func (h *SumsubHandler) GetVerificationStatus(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Invalid address format",
		})
		return
	}

	userAddress := strings.ToLower(address)

	verification, err := h.paymentRepo.GetKYCVerificationByAddress(c.Request.Context(), userAddress)
	if err != nil {
		if errors.Is(err, repository.ErrKYCNotFound) {
			c.JSON(http.StatusNotFound, SumsubResponse{
				Success: false,
				Error:   "No verification found for address",
			})
			return
		}
		h.logger.Error("failed to get verification", zap.Error(err))
		c.JSON(http.StatusInternalServerError, SumsubResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, SumsubResponse{
		Success: true,
		Data: gin.H{
			"status":              verification.Status,
			"sumsub_review_status": verification.SumsubReviewStatus,
			"whitelist_tx_hash":   verification.WhitelistTxHash,
			"submitted_at":        verification.SubmittedAt,
			"verified_at":         verification.VerifiedAt,
			"rejected_at":         verification.RejectedAt,
		},
	})
}

// HandleWebhook handles POST /api/v1/kyc/sumsub/webhook
// @Summary Handle Sumsub webhook events
// @Description Processes Sumsub webhook events (verification completion, etc.)
// @Tags kyc
// @Accept json
// @Produce json
// @Router /api/v1/kyc/sumsub/webhook [post]
func (h *SumsubHandler) HandleWebhook(c *gin.Context) {
	body, err := io.ReadAll(c.Request.Body)
	if err != nil {
		h.logger.Error("failed to read webhook body", zap.Error(err))
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Failed to read request body",
		})
		return
	}

	// Verify webhook signature
	signature := c.GetHeader("X-Payload-Digest")
	if !h.verifyWebhookSignature(body, signature) {
		h.logger.Warn("invalid webhook signature")
		c.JSON(http.StatusUnauthorized, SumsubResponse{
			Success: false,
			Error:   "Invalid signature",
		})
		return
	}

	var payload SumsubWebhookPayload
	if err := json.Unmarshal(body, &payload); err != nil {
		h.logger.Error("failed to parse webhook payload", zap.Error(err))
		c.JSON(http.StatusBadRequest, SumsubResponse{
			Success: false,
			Error:   "Invalid payload",
		})
		return
	}

	ctx := c.Request.Context()

	h.logger.Info("Sumsub webhook received",
		zap.String("type", payload.Type),
		zap.String("applicant_id", payload.ApplicantID),
		zap.String("external_user_id", payload.ExternalUserID),
		zap.String("review_status", payload.ReviewStatus),
	)

	// Find verification by applicant ID
	verification, err := h.paymentRepo.GetKYCVerificationByApplicant(ctx, payload.ApplicantID)
	if err != nil {
		h.logger.Warn("verification not found for applicant", zap.String("applicant_id", payload.ApplicantID))
		// Still return success to avoid webhook retries
		c.JSON(http.StatusOK, SumsubResponse{Success: true})
		return
	}

	// Process based on event type
	update := &repository.KYCVerificationUpdate{
		SumsubInspectionID: &payload.InspectionID,
		SumsubReviewStatus: &payload.ReviewStatus,
	}

	switch payload.Type {
	case "applicantReviewed":
		if payload.ReviewResult != nil {
			update.SumsubReviewResult = payload.ReviewResult

			switch payload.ReviewResult.ReviewAnswer {
			case "GREEN": // Approved
				status := repository.KYCStatusApproved
				update.Status = &status
				h.logger.Info("KYC approved",
					zap.String("user_address", verification.UserAddress),
					zap.String("applicant_id", payload.ApplicantID),
				)
				// TODO: Trigger on-chain whitelist transaction

			case "RED": // Rejected
				status := repository.KYCStatusRejected
				update.Status = &status
				h.logger.Warn("KYC rejected",
					zap.String("user_address", verification.UserAddress),
					zap.Strings("reject_labels", payload.ReviewResult.RejectLabels),
				)
			}
		}

	case "applicantPending":
		status := repository.KYCStatusInReview
		update.Status = &status

	case "applicantCreated":
		// Just log, no status change needed

	case "applicantOnHold":
		status := repository.KYCStatusInReview
		update.Status = &status
	}

	// Update verification record
	if err := h.paymentRepo.UpdateKYCVerification(ctx, verification.ID, update); err != nil {
		h.logger.Error("failed to update verification", zap.Error(err))
	}

	c.JSON(http.StatusOK, SumsubResponse{Success: true})
}

// createSumsubApplicant creates an applicant in Sumsub
func (h *SumsubHandler) createSumsubApplicant(externalUserID string) (*SumsubApplicant, error) {
	url := h.baseURL + "/resources/applicants?levelName=basic-kyc-level"

	body := fmt.Sprintf(`{"externalUserId":"%s"}`, externalUserID)

	req, err := http.NewRequest("POST", url, strings.NewReader(body))
	if err != nil {
		return nil, err
	}

	h.signRequest(req, []byte(body))
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Sumsub API error: %s", string(respBody))
	}

	var applicant SumsubApplicant
	if err := json.NewDecoder(resp.Body).Decode(&applicant); err != nil {
		return nil, err
	}

	return &applicant, nil
}

// getSumsubAccessToken gets an access token for the WebSDK
func (h *SumsubHandler) getSumsubAccessToken(externalUserID string) (*SumsubAccessToken, error) {
	url := fmt.Sprintf("%s/resources/accessTokens?userId=%s&levelName=basic-kyc-level", h.baseURL, externalUserID)

	req, err := http.NewRequest("POST", url, nil)
	if err != nil {
		return nil, err
	}

	h.signRequest(req, nil)

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("Sumsub API error: %s", string(respBody))
	}

	var token SumsubAccessToken
	if err := json.NewDecoder(resp.Body).Decode(&token); err != nil {
		return nil, err
	}

	return &token, nil
}

// signRequest signs a Sumsub API request
func (h *SumsubHandler) signRequest(req *http.Request, body []byte) {
	ts := fmt.Sprintf("%d", time.Now().Unix())
	method := req.Method
	path := req.URL.Path
	if req.URL.RawQuery != "" {
		path += "?" + req.URL.RawQuery
	}

	// Create signature: HMAC-SHA256(ts + method + path + body)
	data := ts + method + path
	if body != nil {
		data += string(body)
	}

	mac := hmac.New(sha256.New, []byte(h.secretKey))
	mac.Write([]byte(data))
	signature := hex.EncodeToString(mac.Sum(nil))

	req.Header.Set("X-App-Token", h.appToken)
	req.Header.Set("X-App-Access-Ts", ts)
	req.Header.Set("X-App-Access-Sig", signature)
}

// verifyWebhookSignature verifies the Sumsub webhook signature
func (h *SumsubHandler) verifyWebhookSignature(body []byte, signature string) bool {
	if h.webhookSecret == "" || signature == "" {
		return false
	}

	mac := hmac.New(sha256.New, []byte(h.webhookSecret))
	mac.Write(body)
	expected := hex.EncodeToString(mac.Sum(nil))

	return hmac.Equal([]byte(expected), []byte(signature))
}
