package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// PricingHandler handles pricing-related API endpoints
type PricingHandler struct {
	repo   repository.PricingRepository
	logger *zap.Logger
}

// NewPricingHandler creates a new pricing handler with injected dependencies
func NewPricingHandler(repo repository.PricingRepository, logger *zap.Logger) *PricingHandler {
	return &PricingHandler{
		repo:   repo,
		logger: logger,
	}
}

// PricingResponse wraps pricing API responses
type PricingResponse struct {
	Success bool               `json:"success"`
	Data    interface{}        `json:"data,omitempty"`
	Message string             `json:"message,omitempty"`
	Error   string             `json:"error,omitempty"`
}

// UpdatePricingRequest represents a request to update pricing
type UpdatePricingRequest struct {
	PriceUSD      *float64 `json:"price_usd,omitempty"`
	PriceETH      *float64 `json:"price_eth,omitempty"`
	PriceNEXUS    *float64 `json:"price_nexus,omitempty"`
	MarkupPercent *float64 `json:"markup_percent,omitempty"`
	IsActive      *bool    `json:"is_active,omitempty"`
	Operator      string   `json:"operator" binding:"required"`
	Reason        string   `json:"reason,omitempty"`
}

// UpdatePaymentMethodRequest represents a request to update a payment method
type UpdatePaymentMethodRequest struct {
	IsActive     *bool    `json:"is_active,omitempty"`
	MinAmountUSD *float64 `json:"min_amount_usd,omitempty"`
	MaxAmountUSD *float64 `json:"max_amount_usd,omitempty"`
	FeePercent   *float64 `json:"fee_percent,omitempty"`
	DisplayOrder *int     `json:"display_order,omitempty"`
	Operator     string   `json:"operator" binding:"required"`
}

// GetPricing handles GET /api/v1/pricing/:serviceCode
// @Summary Get pricing for a service
// @Description Returns pricing information for a specific service
// @Tags pricing
// @Produce json
// @Param serviceCode path string true "Service code (e.g., kyc_verification)"
// @Success 200 {object} PricingResponse
// @Failure 404 {object} PricingResponse
// @Router /api/v1/pricing/{serviceCode} [get]
func (h *PricingHandler) GetPricing(c *gin.Context) {
	serviceCode := c.Param("serviceCode")

	pricing, err := h.repo.GetPricing(c.Request.Context(), serviceCode)
	if err != nil {
		if errors.Is(err, repository.ErrPricingNotFound) {
			c.JSON(http.StatusNotFound, PricingResponse{
				Success: false,
				Error:   "Pricing not found for service: " + serviceCode,
			})
			return
		}
		h.logger.Error("failed to get pricing", zap.String("service", serviceCode), zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data:    pricing,
	})
}

// ListPricing handles GET /api/v1/pricing
// @Summary List all pricing
// @Description Returns all pricing entries
// @Tags pricing
// @Produce json
// @Param active_only query bool false "Only return active pricing (default: false)"
// @Success 200 {object} PricingResponse
// @Router /api/v1/pricing [get]
func (h *PricingHandler) ListPricing(c *gin.Context) {
	activeOnly, _ := strconv.ParseBool(c.DefaultQuery("active_only", "false"))

	pricingList, err := h.repo.ListPricing(c.Request.Context(), activeOnly)
	if err != nil {
		h.logger.Error("failed to list pricing", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data: gin.H{
			"pricing": pricingList,
			"total":   len(pricingList),
		},
	})
}

// UpdatePricing handles PUT /api/v1/pricing/:serviceCode
// @Summary Update pricing for a service (admin only)
// @Description Updates pricing information for a specific service
// @Tags pricing
// @Accept json
// @Produce json
// @Param serviceCode path string true "Service code"
// @Param request body UpdatePricingRequest true "Pricing update request"
// @Success 200 {object} PricingResponse
// @Failure 400 {object} PricingResponse
// @Failure 403 {object} PricingResponse
// @Failure 404 {object} PricingResponse
// @Router /api/v1/pricing/{serviceCode} [put]
func (h *PricingHandler) UpdatePricing(c *gin.Context) {
	serviceCode := c.Param("serviceCode")

	var req UpdatePricingRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, PricingResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate operator address
	if !isValidAddress(req.Operator) {
		c.JSON(http.StatusBadRequest, PricingResponse{
			Success: false,
			Error:   "Invalid operator address format",
		})
		return
	}

	// TODO: Check if operator has ADMIN role via auth middleware

	update := &repository.PricingUpdate{
		PriceUSD:      req.PriceUSD,
		PriceETH:      req.PriceETH,
		PriceNEXUS:    req.PriceNEXUS,
		MarkupPercent: req.MarkupPercent,
		IsActive:      req.IsActive,
		UpdatedBy:     req.Operator,
	}

	err := h.repo.UpdatePricing(c.Request.Context(), serviceCode, update)
	if err != nil {
		if errors.Is(err, repository.ErrPricingNotFound) {
			c.JSON(http.StatusNotFound, PricingResponse{
				Success: false,
				Error:   "Pricing not found for service: " + serviceCode,
			})
			return
		}
		h.logger.Error("failed to update pricing",
			zap.String("service", serviceCode),
			zap.String("operator", req.Operator),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Failed to update pricing",
		})
		return
	}

	// Fetch updated pricing to return
	pricing, _ := h.repo.GetPricing(c.Request.Context(), serviceCode)

	h.logger.Info("pricing updated",
		zap.String("service", serviceCode),
		zap.String("operator", req.Operator),
	)

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data:    pricing,
		Message: "Pricing updated successfully",
	})
}

// GetPricingHistory handles GET /api/v1/pricing/:serviceCode/history
// @Summary Get pricing change history
// @Description Returns the history of pricing changes for a service
// @Tags pricing
// @Produce json
// @Param serviceCode path string true "Service code"
// @Param limit query int false "Number of entries to return (default: 20)"
// @Success 200 {object} PricingResponse
// @Router /api/v1/pricing/{serviceCode}/history [get]
func (h *PricingHandler) GetPricingHistory(c *gin.Context) {
	serviceCode := c.Param("serviceCode")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))

	if limit < 1 || limit > 100 {
		limit = 20
	}

	history, err := h.repo.GetPricingHistory(c.Request.Context(), serviceCode, limit)
	if err != nil {
		h.logger.Error("failed to get pricing history", zap.String("service", serviceCode), zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data: gin.H{
			"service_code": serviceCode,
			"history":      history,
			"total":        len(history),
		},
	})
}

// ListPaymentMethods handles GET /api/v1/payment-methods
// @Summary List available payment methods
// @Description Returns all available payment methods
// @Tags pricing
// @Produce json
// @Param active_only query bool false "Only return active methods (default: true)"
// @Success 200 {object} PricingResponse
// @Router /api/v1/payment-methods [get]
func (h *PricingHandler) ListPaymentMethods(c *gin.Context) {
	activeOnly, _ := strconv.ParseBool(c.DefaultQuery("active_only", "true"))

	methods, err := h.repo.ListPaymentMethods(c.Request.Context(), activeOnly)
	if err != nil {
		h.logger.Error("failed to list payment methods", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data: gin.H{
			"methods": methods,
			"total":   len(methods),
		},
	})
}

// GetPaymentMethod handles GET /api/v1/payment-methods/:methodCode
// @Summary Get a specific payment method
// @Description Returns details for a specific payment method
// @Tags pricing
// @Produce json
// @Param methodCode path string true "Method code (nexus, eth, stripe)"
// @Success 200 {object} PricingResponse
// @Failure 404 {object} PricingResponse
// @Router /api/v1/payment-methods/{methodCode} [get]
func (h *PricingHandler) GetPaymentMethod(c *gin.Context) {
	methodCode := c.Param("methodCode")

	method, err := h.repo.GetPaymentMethod(c.Request.Context(), methodCode)
	if err != nil {
		if errors.Is(err, repository.ErrPaymentMethodNotFound) {
			c.JSON(http.StatusNotFound, PricingResponse{
				Success: false,
				Error:   "Payment method not found: " + methodCode,
			})
			return
		}
		h.logger.Error("failed to get payment method", zap.String("method", methodCode), zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data:    method,
	})
}

// UpdatePaymentMethod handles PUT /api/v1/payment-methods/:methodCode
// @Summary Update a payment method (admin only)
// @Description Updates a payment method configuration
// @Tags pricing
// @Accept json
// @Produce json
// @Param methodCode path string true "Method code"
// @Param request body UpdatePaymentMethodRequest true "Update request"
// @Success 200 {object} PricingResponse
// @Failure 400 {object} PricingResponse
// @Failure 404 {object} PricingResponse
// @Router /api/v1/payment-methods/{methodCode} [put]
func (h *PricingHandler) UpdatePaymentMethod(c *gin.Context) {
	methodCode := c.Param("methodCode")

	var req UpdatePaymentMethodRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, PricingResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Operator) {
		c.JSON(http.StatusBadRequest, PricingResponse{
			Success: false,
			Error:   "Invalid operator address format",
		})
		return
	}

	update := &repository.PaymentMethodUpdate{
		IsActive:     req.IsActive,
		MinAmountUSD: req.MinAmountUSD,
		MaxAmountUSD: req.MaxAmountUSD,
		FeePercent:   req.FeePercent,
		DisplayOrder: req.DisplayOrder,
	}

	err := h.repo.UpdatePaymentMethod(c.Request.Context(), methodCode, update)
	if err != nil {
		if errors.Is(err, repository.ErrPaymentMethodNotFound) {
			c.JSON(http.StatusNotFound, PricingResponse{
				Success: false,
				Error:   "Payment method not found: " + methodCode,
			})
			return
		}
		h.logger.Error("failed to update payment method",
			zap.String("method", methodCode),
			zap.String("operator", req.Operator),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Failed to update payment method",
		})
		return
	}

	method, _ := h.repo.GetPaymentMethod(c.Request.Context(), methodCode)

	h.logger.Info("payment method updated",
		zap.String("method", methodCode),
		zap.String("operator", req.Operator),
	)

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data:    method,
		Message: "Payment method updated successfully",
	})
}

// GetKYCPricing handles GET /api/v1/pricing/kyc
// @Summary Get KYC verification pricing
// @Description Convenience endpoint for KYC verification pricing with all payment options
// @Tags pricing
// @Produce json
// @Success 200 {object} PricingResponse
// @Router /api/v1/pricing/kyc [get]
func (h *PricingHandler) GetKYCPricing(c *gin.Context) {
	ctx := c.Request.Context()

	// Get KYC pricing
	pricing, err := h.repo.GetPricing(ctx, "kyc_verification")
	if err != nil {
		h.logger.Error("failed to get KYC pricing", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Failed to retrieve KYC pricing",
		})
		return
	}

	// Get payment methods
	methods, err := h.repo.ListPaymentMethods(ctx, true)
	if err != nil {
		h.logger.Error("failed to get payment methods", zap.Error(err))
		c.JSON(http.StatusInternalServerError, PricingResponse{
			Success: false,
			Error:   "Failed to retrieve payment methods",
		})
		return
	}

	// Build response with prices per method
	type PaymentOption struct {
		Method      string  `json:"method"`
		MethodName  string  `json:"method_name"`
		Amount      float64 `json:"amount"`
		Currency    string  `json:"currency"`
		FeePercent  float64 `json:"fee_percent"`
		TotalAmount float64 `json:"total_amount"`
	}

	var options []PaymentOption
	for _, m := range methods {
		var amount float64
		var currency string

		switch m.MethodCode {
		case "nexus":
			if pricing.PriceNEXUS != nil {
				amount = *pricing.PriceNEXUS
				currency = "NEXUS"
			}
		case "eth":
			if pricing.PriceETH != nil {
				amount = *pricing.PriceETH
				currency = "ETH"
			}
		case "stripe":
			amount = pricing.PriceUSD
			currency = "USD"
		}

		if amount > 0 {
			fee := amount * (m.FeePercent / 100)
			options = append(options, PaymentOption{
				Method:      m.MethodCode,
				MethodName:  m.MethodName,
				Amount:      amount,
				Currency:    currency,
				FeePercent:  m.FeePercent,
				TotalAmount: amount + fee,
			})
		}
	}

	c.JSON(http.StatusOK, PricingResponse{
		Success: true,
		Data: gin.H{
			"service":         "kyc_verification",
			"service_name":    pricing.ServiceName,
			"description":     pricing.Description,
			"base_price_usd":  pricing.PriceUSD,
			"payment_options": options,
		},
	})
}
