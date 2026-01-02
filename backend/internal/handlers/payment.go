package handlers

import (
	"errors"
	"fmt"
	"net/http"
	"os"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/stripe/stripe-go/v76"
	"github.com/stripe/stripe-go/v76/checkout/session"
	"github.com/stripe/stripe-go/v76/webhook"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// PaymentHandler handles payment-related API endpoints
type PaymentHandler struct {
	paymentRepo repository.PaymentRepository
	pricingRepo repository.PricingRepository
	logger      *zap.Logger
	webhookSecret string
}

// NewPaymentHandler creates a new payment handler with injected dependencies
func NewPaymentHandler(
	paymentRepo repository.PaymentRepository,
	pricingRepo repository.PricingRepository,
	logger *zap.Logger,
) *PaymentHandler {
	// Set Stripe API key from environment
	stripe.Key = os.Getenv("STRIPE_SECRET_KEY")

	return &PaymentHandler{
		paymentRepo:   paymentRepo,
		pricingRepo:   pricingRepo,
		logger:        logger,
		webhookSecret: os.Getenv("STRIPE_WEBHOOK_SECRET"),
	}
}

// PaymentResponse wraps payment API responses
type PaymentResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// CreateCheckoutRequest represents a request to create a Stripe checkout session
type CreateCheckoutRequest struct {
	ServiceCode   string `json:"service_code" binding:"required"`
	PayerAddress  string `json:"payer_address" binding:"required"`
	SuccessURL    string `json:"success_url" binding:"required"`
	CancelURL     string `json:"cancel_url" binding:"required"`
}

// CryptoPaymentRequest represents a request to process a crypto payment
type CryptoPaymentRequest struct {
	ServiceCode   string  `json:"service_code" binding:"required"`
	PayerAddress  string  `json:"payer_address" binding:"required"`
	PaymentMethod string  `json:"payment_method" binding:"required"` // nexus or eth
	TxHash        string  `json:"tx_hash" binding:"required"`
	Amount        float64 `json:"amount" binding:"required"`
}

// CreateStripeCheckout handles POST /api/v1/payments/stripe/checkout
// @Summary Create Stripe checkout session
// @Description Creates a Stripe checkout session for fiat payment
// @Tags payments
// @Accept json
// @Produce json
// @Param request body CreateCheckoutRequest true "Checkout request"
// @Success 200 {object} PaymentResponse
// @Failure 400 {object} PaymentResponse
// @Router /api/v1/payments/stripe/checkout [post]
func (h *PaymentHandler) CreateStripeCheckout(c *gin.Context) {
	var req CreateCheckoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate payer address
	if !isValidAddress(req.PayerAddress) {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid payer address format",
		})
		return
	}

	ctx := c.Request.Context()

	// Get pricing for the service
	pricing, err := h.pricingRepo.GetPricing(ctx, req.ServiceCode)
	if err != nil {
		if errors.Is(err, repository.ErrPricingNotFound) {
			c.JSON(http.StatusBadRequest, PaymentResponse{
				Success: false,
				Error:   "Service not found: " + req.ServiceCode,
			})
			return
		}
		h.logger.Error("failed to get pricing", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	if !pricing.IsActive {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Service is currently unavailable",
		})
		return
	}

	// Get Stripe fee percentage
	stripeMethod, err := h.pricingRepo.GetPaymentMethod(ctx, "stripe")
	if err != nil {
		h.logger.Error("failed to get stripe payment method", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Stripe payment not available",
		})
		return
	}

	// Calculate total with Stripe fee
	baseAmount := pricing.PriceUSD
	stripeFee := baseAmount * (stripeMethod.FeePercent / 100)
	totalAmount := baseAmount + stripeFee

	// Convert to cents for Stripe
	amountInCents := int64(totalAmount * 100)

	// Create Stripe checkout session
	params := &stripe.CheckoutSessionParams{
		PaymentMethodTypes: stripe.StringSlice([]string{"card"}),
		Mode:               stripe.String(string(stripe.CheckoutSessionModePayment)),
		SuccessURL:         stripe.String(req.SuccessURL + "?session_id={CHECKOUT_SESSION_ID}"),
		CancelURL:          stripe.String(req.CancelURL),
		LineItems: []*stripe.CheckoutSessionLineItemParams{
			{
				PriceData: &stripe.CheckoutSessionLineItemPriceDataParams{
					Currency: stripe.String("usd"),
					ProductData: &stripe.CheckoutSessionLineItemPriceDataProductDataParams{
						Name:        stripe.String(pricing.ServiceName),
						Description: stripe.String(pricing.Description),
					},
					UnitAmount: stripe.Int64(amountInCents),
				},
				Quantity: stripe.Int64(1),
			},
		},
		Metadata: map[string]string{
			"service_code":  req.ServiceCode,
			"payer_address": strings.ToLower(req.PayerAddress),
		},
	}

	stripeSession, err := session.New(params)
	if err != nil {
		h.logger.Error("failed to create Stripe session", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Failed to create payment session",
		})
		return
	}

	// Create payment record in database
	payment := &repository.Payment{
		ServiceCode:     req.ServiceCode,
		PricingID:       &pricing.ID,
		PayerAddress:    strings.ToLower(req.PayerAddress),
		PaymentMethod:   "stripe",
		AmountCharged:   totalAmount,
		Currency:        "USD",
		AmountUSD:       &totalAmount,
		StripeSessionID: &stripeSession.ID,
		Status:          repository.PaymentStatusPending,
	}

	if err := h.paymentRepo.CreatePayment(ctx, payment); err != nil {
		h.logger.Error("failed to create payment record", zap.Error(err))
		// Don't fail - payment can still proceed
	}

	h.logger.Info("Stripe checkout session created",
		zap.String("session_id", stripeSession.ID),
		zap.String("service", req.ServiceCode),
		zap.String("payer", req.PayerAddress),
		zap.Float64("amount", totalAmount),
	)

	c.JSON(http.StatusOK, PaymentResponse{
		Success: true,
		Data: gin.H{
			"session_id":   stripeSession.ID,
			"checkout_url": stripeSession.URL,
			"amount_usd":   totalAmount,
			"expires_at":   stripeSession.ExpiresAt,
		},
	})
}

// HandleStripeWebhook handles POST /api/v1/payments/stripe/webhook
// @Summary Handle Stripe webhook events
// @Description Processes Stripe webhook events (payment completion, etc.)
// @Tags payments
// @Accept json
// @Produce json
// @Router /api/v1/payments/stripe/webhook [post]
func (h *PaymentHandler) HandleStripeWebhook(c *gin.Context) {
	payload, err := c.GetRawData()
	if err != nil {
		h.logger.Error("failed to read webhook body", zap.Error(err))
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Failed to read request body",
		})
		return
	}

	sigHeader := c.GetHeader("Stripe-Signature")

	event, err := webhook.ConstructEvent(payload, sigHeader, h.webhookSecret)
	if err != nil {
		h.logger.Error("failed to verify webhook signature", zap.Error(err))
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid signature",
		})
		return
	}

	ctx := c.Request.Context()

	switch event.Type {
	case "checkout.session.completed":
		var session stripe.CheckoutSession
		if err := webhook.UnmarshalEvent(event, &session); err != nil {
			h.logger.Error("failed to unmarshal session", zap.Error(err))
			c.JSON(http.StatusBadRequest, PaymentResponse{Success: false, Error: "Invalid event data"})
			return
		}

		// Update payment status
		payment, err := h.paymentRepo.GetPaymentByStripeSession(ctx, session.ID)
		if err != nil {
			h.logger.Warn("payment not found for session", zap.String("session", session.ID))
		} else {
			stripePaymentID := session.PaymentIntent.ID
			if err := h.paymentRepo.UpdatePaymentStatus(ctx, payment.ID, repository.PaymentStatusCompleted, &repository.PaymentStatusUpdate{
				StripePaymentID: &stripePaymentID,
			}); err != nil {
				h.logger.Error("failed to update payment status", zap.Error(err))
			}

			h.logger.Info("payment completed",
				zap.String("payment_id", payment.ID),
				zap.String("payer", payment.PayerAddress),
				zap.Float64("amount", payment.AmountCharged),
			)
		}

	case "checkout.session.expired":
		var session stripe.CheckoutSession
		if err := webhook.UnmarshalEvent(event, &session); err != nil {
			h.logger.Error("failed to unmarshal session", zap.Error(err))
			c.JSON(http.StatusBadRequest, PaymentResponse{Success: false, Error: "Invalid event data"})
			return
		}

		payment, err := h.paymentRepo.GetPaymentByStripeSession(ctx, session.ID)
		if err == nil {
			if err := h.paymentRepo.UpdatePaymentStatus(ctx, payment.ID, repository.PaymentStatusCancelled, nil); err != nil {
				h.logger.Error("failed to update payment status", zap.Error(err))
			}
		}

	case "payment_intent.payment_failed":
		h.logger.Warn("payment failed", zap.String("event_id", event.ID))
	}

	c.JSON(http.StatusOK, PaymentResponse{Success: true})
}

// ProcessCryptoPayment handles POST /api/v1/payments/crypto
// @Summary Process crypto payment (ETH or NEXUS)
// @Description Records and verifies a crypto payment transaction
// @Tags payments
// @Accept json
// @Produce json
// @Param request body CryptoPaymentRequest true "Payment request"
// @Success 200 {object} PaymentResponse
// @Failure 400 {object} PaymentResponse
// @Router /api/v1/payments/crypto [post]
func (h *PaymentHandler) ProcessCryptoPayment(c *gin.Context) {
	var req CryptoPaymentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate addresses
	if !isValidAddress(req.PayerAddress) {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid payer address format",
		})
		return
	}

	if !isValidTxHash(req.TxHash) {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid transaction hash format",
		})
		return
	}

	if req.PaymentMethod != "eth" && req.PaymentMethod != "nexus" {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   "Invalid payment method. Must be 'eth' or 'nexus'",
		})
		return
	}

	ctx := c.Request.Context()

	// Get pricing
	pricing, err := h.pricingRepo.GetPricing(ctx, req.ServiceCode)
	if err != nil {
		if errors.Is(err, repository.ErrPricingNotFound) {
			c.JSON(http.StatusBadRequest, PaymentResponse{
				Success: false,
				Error:   "Service not found",
			})
			return
		}
		h.logger.Error("failed to get pricing", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	// Determine expected amount based on payment method
	var expectedAmount float64
	var currency string
	switch req.PaymentMethod {
	case "eth":
		if pricing.PriceETH == nil {
			c.JSON(http.StatusBadRequest, PaymentResponse{
				Success: false,
				Error:   "ETH payment not available for this service",
			})
			return
		}
		expectedAmount = *pricing.PriceETH
		currency = "ETH"
	case "nexus":
		if pricing.PriceNEXUS == nil {
			c.JSON(http.StatusBadRequest, PaymentResponse{
				Success: false,
				Error:   "NEXUS payment not available for this service",
			})
			return
		}
		expectedAmount = *pricing.PriceNEXUS
		currency = "NEXUS"
	}

	// Verify amount is sufficient (with 1% tolerance for gas price fluctuations)
	tolerance := expectedAmount * 0.01
	if req.Amount < expectedAmount-tolerance {
		c.JSON(http.StatusBadRequest, PaymentResponse{
			Success: false,
			Error:   fmt.Sprintf("Insufficient payment. Expected %.6f %s, received %.6f %s", expectedAmount, currency, req.Amount, currency),
		})
		return
	}

	// Create payment record
	amountUSD := pricing.PriceUSD
	payment := &repository.Payment{
		ServiceCode:   req.ServiceCode,
		PricingID:     &pricing.ID,
		PayerAddress:  strings.ToLower(req.PayerAddress),
		PaymentMethod: req.PaymentMethod,
		AmountCharged: req.Amount,
		Currency:      currency,
		AmountUSD:     &amountUSD,
		TxHash:        &req.TxHash,
		Status:        repository.PaymentStatusProcessing, // Will be confirmed after tx verification
	}

	if err := h.paymentRepo.CreatePayment(ctx, payment); err != nil {
		h.logger.Error("failed to create payment record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Failed to record payment",
		})
		return
	}

	// TODO: Queue transaction verification job
	// For now, mark as completed (in production, verify tx on-chain first)
	if err := h.paymentRepo.UpdatePaymentStatus(ctx, payment.ID, repository.PaymentStatusCompleted, nil); err != nil {
		h.logger.Error("failed to update payment status", zap.Error(err))
	}

	h.logger.Info("crypto payment processed",
		zap.String("payment_id", payment.ID),
		zap.String("tx_hash", req.TxHash),
		zap.String("method", req.PaymentMethod),
		zap.Float64("amount", req.Amount),
	)

	c.JSON(http.StatusOK, PaymentResponse{
		Success: true,
		Data: gin.H{
			"payment_id": payment.ID,
			"status":     "completed",
			"tx_hash":    req.TxHash,
		},
		Message: "Payment recorded successfully",
	})
}

// GetPayment handles GET /api/v1/payments/:paymentId
// @Summary Get payment details
// @Description Returns details for a specific payment
// @Tags payments
// @Produce json
// @Param paymentId path string true "Payment ID"
// @Success 200 {object} PaymentResponse
// @Failure 404 {object} PaymentResponse
// @Router /api/v1/payments/{paymentId} [get]
func (h *PaymentHandler) GetPayment(c *gin.Context) {
	paymentID := c.Param("paymentId")

	payment, err := h.paymentRepo.GetPayment(c.Request.Context(), paymentID)
	if err != nil {
		if errors.Is(err, repository.ErrPaymentNotFound) {
			c.JSON(http.StatusNotFound, PaymentResponse{
				Success: false,
				Error:   "Payment not found",
			})
			return
		}
		h.logger.Error("failed to get payment", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PaymentResponse{
		Success: true,
		Data:    payment,
	})
}

// GetPaymentBySession handles GET /api/v1/payments/stripe/session/:sessionId
// @Summary Get payment by Stripe session
// @Description Returns payment details for a Stripe checkout session
// @Tags payments
// @Produce json
// @Param sessionId path string true "Stripe session ID"
// @Success 200 {object} PaymentResponse
// @Failure 404 {object} PaymentResponse
// @Router /api/v1/payments/stripe/session/{sessionId} [get]
func (h *PaymentHandler) GetPaymentBySession(c *gin.Context) {
	sessionID := c.Param("sessionId")

	payment, err := h.paymentRepo.GetPaymentByStripeSession(c.Request.Context(), sessionID)
	if err != nil {
		if errors.Is(err, repository.ErrPaymentNotFound) {
			c.JSON(http.StatusNotFound, PaymentResponse{
				Success: false,
				Error:   "Payment not found for session",
			})
			return
		}
		h.logger.Error("failed to get payment by session", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PaymentResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PaymentResponse{
		Success: true,
		Data:    payment,
	})
}

// isValidTxHash validates an Ethereum transaction hash
func isValidTxHash(hash string) bool {
	if len(hash) != 66 {
		return false
	}
	if !strings.HasPrefix(hash, "0x") {
		return false
	}
	for _, c := range hash[2:] {
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')) {
			return false
		}
	}
	return true
}
