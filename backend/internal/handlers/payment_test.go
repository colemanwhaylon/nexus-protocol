package handlers_test

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/handlers"
	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// MockPaymentRepository implements repository.PaymentRepository for testing
type MockPaymentRepository struct {
	mock.Mock
}

func (m *MockPaymentRepository) CreatePayment(ctx context.Context, payment *repository.Payment) error {
	args := m.Called(ctx, payment)
	// Simulate ID generation
	if payment.ID == "" {
		payment.ID = "pay-" + time.Now().Format("20060102150405")
	}
	return args.Error(0)
}

func (m *MockPaymentRepository) GetPayment(ctx context.Context, id string) (*repository.Payment, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.Payment), args.Error(1)
}

func (m *MockPaymentRepository) GetPaymentByStripeSession(ctx context.Context, sessionID string) (*repository.Payment, error) {
	args := m.Called(ctx, sessionID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.Payment), args.Error(1)
}

func (m *MockPaymentRepository) UpdatePaymentStatus(ctx context.Context, id string, status repository.PaymentStatus, details *repository.PaymentStatusUpdate) error {
	args := m.Called(ctx, id, status, details)
	return args.Error(0)
}

func (m *MockPaymentRepository) ListPayments(ctx context.Context, filter repository.PaymentFilter, page repository.Pagination) ([]*repository.Payment, int64, error) {
	args := m.Called(ctx, filter, page)
	if args.Get(0) == nil {
		return nil, 0, args.Error(2)
	}
	return args.Get(0).([]*repository.Payment), args.Get(1).(int64), args.Error(2)
}

func (m *MockPaymentRepository) CreateKYCVerification(ctx context.Context, verification *repository.KYCVerification) error {
	args := m.Called(ctx, verification)
	return args.Error(0)
}

func (m *MockPaymentRepository) GetKYCVerification(ctx context.Context, id string) (*repository.KYCVerification, error) {
	args := m.Called(ctx, id)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.KYCVerification), args.Error(1)
}

func (m *MockPaymentRepository) GetKYCVerificationByAddress(ctx context.Context, address string) (*repository.KYCVerification, error) {
	args := m.Called(ctx, address)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.KYCVerification), args.Error(1)
}

func (m *MockPaymentRepository) GetKYCVerificationByApplicant(ctx context.Context, applicantID string) (*repository.KYCVerification, error) {
	args := m.Called(ctx, applicantID)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.KYCVerification), args.Error(1)
}

func (m *MockPaymentRepository) UpdateKYCVerification(ctx context.Context, id string, update *repository.KYCVerificationUpdate) error {
	args := m.Called(ctx, id, update)
	return args.Error(0)
}

func (m *MockPaymentRepository) ListKYCVerifications(ctx context.Context, filter repository.KYCVerificationFilter, page repository.Pagination) ([]*repository.KYCVerification, int64, error) {
	args := m.Called(ctx, filter, page)
	if args.Get(0) == nil {
		return nil, 0, args.Error(2)
	}
	return args.Get(0).([]*repository.KYCVerification), args.Get(1).(int64), args.Error(2)
}

// Helper functions for payment tests
func setupPaymentTestRouter(handler *handlers.PaymentHandler) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	api := router.Group("/api/v1")
	{
		payments := api.Group("/payments")
		{
			payments.GET("/:paymentId", handler.GetPayment)
			payments.POST("/stripe/checkout", handler.CreateStripeCheckout)
			payments.POST("/stripe/webhook", handler.HandleStripeWebhook)
			payments.GET("/stripe/session/:sessionId", handler.GetPaymentBySession)
			payments.POST("/crypto", handler.ProcessCryptoPayment)
		}
	}

	return router
}

func createTestPayment() *repository.Payment {
	amountUSD := 15.0
	return &repository.Payment{
		ID:            "pay-001",
		ServiceCode:   "kyc_verification",
		PricingID:     stringPtr("price-001"),
		PayerAddress:  "0x1234567890123456789012345678901234567890",
		PaymentMethod: "stripe",
		AmountCharged: 15.45,
		Currency:      "USD",
		AmountUSD:     &amountUSD,
		Status:        repository.PaymentStatusCompleted,
		CreatedAt:     time.Now().Add(-1 * time.Hour),
		UpdatedAt:     time.Now(),
	}
}

func createTestPricingForPayment() *repository.Pricing {
	priceETH := 0.005
	priceNEXUS := 100.0
	return &repository.Pricing{
		ID:            "price-001",
		ServiceCode:   "kyc_verification",
		ServiceName:   "KYC Verification",
		Description:   "Identity verification service",
		CostUSD:       10.0,
		PriceUSD:      15.0,
		PriceETH:      &priceETH,
		PriceNEXUS:    &priceNEXUS,
		MarkupPercent: 50.0,
		IsActive:      true,
	}
}

func stringPtr(s string) *string {
	return &s
}

// Tests for GetPayment
func TestPaymentHandler_GetPayment(t *testing.T) {
	tests := []struct {
		name           string
		paymentID      string
		setupMock      func(*MockPaymentRepository, *MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:      "success - returns payment details",
			paymentID: "pay-001",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payRepo.On("GetPayment", mock.Anything, "pay-001").
					Return(createTestPayment(), nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.NotNil(t, body["data"])
			},
		},
		{
			name:      "not found - unknown payment ID",
			paymentID: "pay-unknown",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payRepo.On("GetPayment", mock.Anything, "pay-unknown").
					Return(nil, repository.ErrPaymentNotFound)
			},
			expectedStatus: http.StatusNotFound,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Payment not found", body["error"])
			},
		},
		{
			name:      "internal error - database failure",
			paymentID: "pay-001",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payRepo.On("GetPayment", mock.Anything, "pay-001").
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Internal server error", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)
			tt.setupMock(mockPayRepo, mockPriceRepo)

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/payments/"+tt.paymentID, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockPayRepo.AssertExpectations(t)
		})
	}
}

// Tests for GetPaymentBySession
func TestPaymentHandler_GetPaymentBySession(t *testing.T) {
	tests := []struct {
		name           string
		sessionID      string
		setupMock      func(*MockPaymentRepository, *MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:      "success - returns payment for session",
			sessionID: "cs_test_session123",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payment := createTestPayment()
				payment.StripeSessionID = stringPtr("cs_test_session123")
				payRepo.On("GetPaymentByStripeSession", mock.Anything, "cs_test_session123").
					Return(payment, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.NotNil(t, body["data"])
			},
		},
		{
			name:      "not found - unknown session",
			sessionID: "cs_unknown",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payRepo.On("GetPaymentByStripeSession", mock.Anything, "cs_unknown").
					Return(nil, repository.ErrPaymentNotFound)
			},
			expectedStatus: http.StatusNotFound,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Payment not found for session", body["error"])
			},
		},
		{
			name:      "internal error - database failure",
			sessionID: "cs_test_session123",
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				payRepo.On("GetPaymentByStripeSession", mock.Anything, "cs_test_session123").
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Internal server error", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)
			tt.setupMock(mockPayRepo, mockPriceRepo)

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/payments/stripe/session/"+tt.sessionID, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockPayRepo.AssertExpectations(t)
		})
	}
}

// Tests for ProcessCryptoPayment
func TestPaymentHandler_ProcessCryptoPayment(t *testing.T) {
	validAddress := "0x1234567890123456789012345678901234567890"
	validTxHash := "0x1234567890123456789012345678901234567890123456789012345678901234"

	tests := []struct {
		name           string
		requestBody    interface{}
		setupMock      func(*MockPaymentRepository, *MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name: "success - ETH payment processed",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricingForPayment(), nil)
				payRepo.On("CreatePayment", mock.Anything, mock.AnythingOfType("*repository.Payment")).
					Return(nil)
				payRepo.On("UpdatePaymentStatus", mock.Anything, mock.Anything, repository.PaymentStatusCompleted, mock.Anything).
					Return(nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.Equal(t, "Payment recorded successfully", body["message"])
				data := body["data"].(map[string]interface{})
				assert.Equal(t, "completed", data["status"])
			},
		},
		{
			name: "success - NEXUS payment processed",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "nexus",
				"tx_hash":        validTxHash,
				"amount":         100.0,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricingForPayment(), nil)
				payRepo.On("CreatePayment", mock.Anything, mock.AnythingOfType("*repository.Payment")).
					Return(nil)
				payRepo.On("UpdatePaymentStatus", mock.Anything, mock.Anything, repository.PaymentStatusCompleted, mock.Anything).
					Return(nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
			},
		},
		{
			name: "bad request - missing required fields",
			requestBody: map[string]interface{}{
				"service_code": "kyc_verification",
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Invalid request")
			},
		},
		{
			name: "bad request - invalid payer address",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  "invalid-address",
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid payer address format", body["error"])
			},
		},
		{
			name: "bad request - invalid tx hash",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        "invalid-tx-hash",
				"amount":         0.005,
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid transaction hash format", body["error"])
			},
		},
		{
			name: "bad request - invalid payment method",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "bitcoin",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Invalid payment method")
			},
		},
		{
			name: "bad request - service not found",
			requestBody: map[string]interface{}{
				"service_code":   "unknown_service",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "unknown_service").
					Return(nil, repository.ErrPricingNotFound)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Service not found", body["error"])
			},
		},
		{
			name: "bad request - ETH payment not available",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				pricing := createTestPricingForPayment()
				pricing.PriceETH = nil // ETH not available
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(pricing, nil)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "ETH payment not available for this service", body["error"])
			},
		},
		{
			name: "bad request - NEXUS payment not available",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "nexus",
				"tx_hash":        validTxHash,
				"amount":         100.0,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				pricing := createTestPricingForPayment()
				pricing.PriceNEXUS = nil // NEXUS not available
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(pricing, nil)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "NEXUS payment not available for this service", body["error"])
			},
		},
		{
			name: "bad request - insufficient payment amount",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.001, // Less than required 0.005
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricingForPayment(), nil)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Insufficient payment")
			},
		},
		{
			name: "internal error - failed to create payment record",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricingForPayment(), nil)
				payRepo.On("CreatePayment", mock.Anything, mock.AnythingOfType("*repository.Payment")).
					Return(repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Failed to record payment", body["error"])
			},
		},
		{
			name: "internal error - pricing fetch failure",
			requestBody: map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         0.005,
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Internal server error", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)
			tt.setupMock(mockPayRepo, mockPriceRepo)

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			reqBody, _ := json.Marshal(tt.requestBody)
			req, _ := http.NewRequest("POST", "/api/v1/payments/crypto", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockPayRepo.AssertExpectations(t)
			mockPriceRepo.AssertExpectations(t)
		})
	}
}

// Tests for CreateStripeCheckout - validation only (Stripe API not mocked)
func TestPaymentHandler_CreateStripeCheckout_Validation(t *testing.T) {
	validAddress := "0x1234567890123456789012345678901234567890"

	tests := []struct {
		name           string
		requestBody    interface{}
		setupMock      func(*MockPaymentRepository, *MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name: "bad request - missing required fields",
			requestBody: map[string]interface{}{
				"service_code": "kyc_verification",
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Invalid request")
			},
		},
		{
			name: "bad request - invalid payer address",
			requestBody: map[string]interface{}{
				"service_code":  "kyc_verification",
				"payer_address": "invalid",
				"success_url":   "https://example.com/success",
				"cancel_url":    "https://example.com/cancel",
			},
			setupMock:      func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid payer address format", body["error"])
			},
		},
		{
			name: "bad request - service not found",
			requestBody: map[string]interface{}{
				"service_code":  "unknown_service",
				"payer_address": validAddress,
				"success_url":   "https://example.com/success",
				"cancel_url":    "https://example.com/cancel",
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "unknown_service").
					Return(nil, repository.ErrPricingNotFound)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Service not found")
			},
		},
		{
			name: "bad request - service unavailable (inactive)",
			requestBody: map[string]interface{}{
				"service_code":  "kyc_verification",
				"payer_address": validAddress,
				"success_url":   "https://example.com/success",
				"cancel_url":    "https://example.com/cancel",
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				pricing := createTestPricingForPayment()
				pricing.IsActive = false
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(pricing, nil)
			},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Service is currently unavailable", body["error"])
			},
		},
		{
			name: "internal error - stripe payment method not found",
			requestBody: map[string]interface{}{
				"service_code":  "kyc_verification",
				"payer_address": validAddress,
				"success_url":   "https://example.com/success",
				"cancel_url":    "https://example.com/cancel",
			},
			setupMock: func(payRepo *MockPaymentRepository, priceRepo *MockPricingRepository) {
				priceRepo.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricingForPayment(), nil)
				priceRepo.On("GetPaymentMethod", mock.Anything, "stripe").
					Return(nil, repository.ErrPaymentMethodNotFound)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Stripe payment not available", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)
			tt.setupMock(mockPayRepo, mockPriceRepo)

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			reqBody, _ := json.Marshal(tt.requestBody)
			req, _ := http.NewRequest("POST", "/api/v1/payments/stripe/checkout", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockPayRepo.AssertExpectations(t)
			mockPriceRepo.AssertExpectations(t)
		})
	}
}

// Tests for HandleStripeWebhook - signature validation
func TestPaymentHandler_HandleStripeWebhook_Validation(t *testing.T) {
	tests := []struct {
		name           string
		body           string
		signature      string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "bad request - invalid signature",
			body:           `{"type": "checkout.session.completed"}`,
			signature:      "invalid-signature",
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid signature", body["error"])
			},
		},
		{
			name:           "bad request - missing signature",
			body:           `{"type": "checkout.session.completed"}`,
			signature:      "",
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			req, _ := http.NewRequest("POST", "/api/v1/payments/stripe/webhook", bytes.NewBufferString(tt.body))
			req.Header.Set("Content-Type", "application/json")
			if tt.signature != "" {
				req.Header.Set("Stripe-Signature", tt.signature)
			}
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}
		})
	}
}

// Tests for edge cases with payment tolerance
func TestPaymentHandler_ProcessCryptoPayment_Tolerance(t *testing.T) {
	validAddress := "0x1234567890123456789012345678901234567890"
	validTxHash := "0x1234567890123456789012345678901234567890123456789012345678901234"

	tests := []struct {
		name           string
		amount         float64
		expectedPrice  float64
		shouldPass     bool
	}{
		{
			name:          "exactly at price",
			amount:        0.005,
			expectedPrice: 0.005,
			shouldPass:    true,
		},
		{
			name:          "within 1% tolerance (0.5% under)",
			amount:        0.004975, // 0.5% under 0.005
			expectedPrice: 0.005,
			shouldPass:    true,
		},
		{
			name:          "at 1% tolerance boundary",
			amount:        0.00495, // exactly 1% under
			expectedPrice: 0.005,
			shouldPass:    true,
		},
		{
			name:          "just under 1% tolerance",
			amount:        0.00494, // just over 1% under
			expectedPrice: 0.005,
			shouldPass:    false,
		},
		{
			name:          "above price (overpayment allowed)",
			amount:        0.006, // 20% over
			expectedPrice: 0.005,
			shouldPass:    true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockPayRepo := new(MockPaymentRepository)
			mockPriceRepo := new(MockPricingRepository)

			pricing := createTestPricingForPayment()
			pricing.PriceETH = &tt.expectedPrice
			mockPriceRepo.On("GetPricing", mock.Anything, "kyc_verification").
				Return(pricing, nil)

			if tt.shouldPass {
				mockPayRepo.On("CreatePayment", mock.Anything, mock.AnythingOfType("*repository.Payment")).
					Return(nil)
				mockPayRepo.On("UpdatePaymentStatus", mock.Anything, mock.Anything, repository.PaymentStatusCompleted, mock.Anything).
					Return(nil)
			}

			logger := zap.NewNop()
			handler := handlers.NewPaymentHandler(mockPayRepo, mockPriceRepo, logger)
			router := setupPaymentTestRouter(handler)

			reqBody, _ := json.Marshal(map[string]interface{}{
				"service_code":   "kyc_verification",
				"payer_address":  validAddress,
				"payment_method": "eth",
				"tx_hash":        validTxHash,
				"amount":         tt.amount,
			})
			req, _ := http.NewRequest("POST", "/api/v1/payments/crypto", bytes.NewBuffer(reqBody))
			req.Header.Set("Content-Type", "application/json")
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			if tt.shouldPass {
				assert.Equal(t, http.StatusOK, resp.Code)
			} else {
				assert.Equal(t, http.StatusBadRequest, resp.Code)
			}

			mockPayRepo.AssertExpectations(t)
			mockPriceRepo.AssertExpectations(t)
		})
	}
}
