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

// MockPricingRepository implements repository.PricingRepository for testing
type MockPricingRepository struct {
	mock.Mock
}

func (m *MockPricingRepository) GetPricing(ctx context.Context, serviceCode string) (*repository.Pricing, error) {
	args := m.Called(ctx, serviceCode)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.Pricing), args.Error(1)
}

func (m *MockPricingRepository) ListPricing(ctx context.Context, activeOnly bool) ([]*repository.Pricing, error) {
	args := m.Called(ctx, activeOnly)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*repository.Pricing), args.Error(1)
}

func (m *MockPricingRepository) UpdatePricing(ctx context.Context, serviceCode string, update *repository.PricingUpdate) error {
	args := m.Called(ctx, serviceCode, update)
	return args.Error(0)
}

func (m *MockPricingRepository) GetPaymentMethod(ctx context.Context, methodCode string) (*repository.PaymentMethod, error) {
	args := m.Called(ctx, methodCode)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).(*repository.PaymentMethod), args.Error(1)
}

func (m *MockPricingRepository) ListPaymentMethods(ctx context.Context, activeOnly bool) ([]*repository.PaymentMethod, error) {
	args := m.Called(ctx, activeOnly)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*repository.PaymentMethod), args.Error(1)
}

func (m *MockPricingRepository) UpdatePaymentMethod(ctx context.Context, methodCode string, update *repository.PaymentMethodUpdate) error {
	args := m.Called(ctx, methodCode, update)
	return args.Error(0)
}

func (m *MockPricingRepository) GetPricingHistory(ctx context.Context, serviceCode string, limit int) ([]*repository.PricingHistoryEntry, error) {
	args := m.Called(ctx, serviceCode, limit)
	if args.Get(0) == nil {
		return nil, args.Error(1)
	}
	return args.Get(0).([]*repository.PricingHistoryEntry), args.Error(1)
}

// Helper functions for tests
func setupPricingTestRouter(handler *handlers.PricingHandler) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	api := router.Group("/api/v1")
	{
		api.GET("/pricing", handler.ListPricing)
		api.GET("/pricing/kyc", handler.GetKYCPricing)
		api.GET("/pricing/:serviceCode", handler.GetPricing)
		api.PUT("/pricing/:serviceCode", handler.UpdatePricing)
		api.GET("/pricing/:serviceCode/history", handler.GetPricingHistory)
		api.GET("/payment-methods", handler.ListPaymentMethods)
		api.GET("/payment-methods/:methodCode", handler.GetPaymentMethod)
		api.PUT("/payment-methods/:methodCode", handler.UpdatePaymentMethod)
	}

	return router
}

func createTestPricing() *repository.Pricing {
	priceETH := 0.005
	priceNEXUS := 100.0
	return &repository.Pricing{
		ID:            "price-001",
		ServiceCode:   "kyc_verification",
		ServiceName:   "KYC Verification",
		Description:   "Know Your Customer verification",
		CostUSD:       10.0,
		CostProvider:  "sumsub",
		PriceUSD:      15.0,
		PriceETH:      &priceETH,
		PriceNEXUS:    &priceNEXUS,
		MarkupPercent: 50.0,
		IsActive:      true,
		CreatedAt:     time.Now().Add(-24 * time.Hour),
		UpdatedAt:     time.Now(),
		UpdatedBy:     "0x1234567890123456789012345678901234567890",
	}
}

func createTestPaymentMethod(code string) *repository.PaymentMethod {
	return &repository.PaymentMethod{
		ID:           "method-001",
		MethodCode:   code,
		MethodName:   code + " Payment",
		IsActive:     true,
		MinAmountUSD: 1.0,
		MaxAmountUSD: nil,
		FeePercent:   2.9,
		DisplayOrder: 1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}
}

// Tests for GetPricing
func TestPricingHandler_GetPricing(t *testing.T) {
	tests := []struct {
		name           string
		serviceCode    string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		expectedBody   map[string]interface{}
	}{
		{
			name:        "success - returns pricing for valid service code",
			serviceCode: "kyc_verification",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricing(), nil)
			},
			expectedStatus: http.StatusOK,
			expectedBody: map[string]interface{}{
				"success": true,
			},
		},
		{
			name:        "not found - returns 404 for unknown service",
			serviceCode: "unknown_service",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "unknown_service").
					Return(nil, repository.ErrPricingNotFound)
			},
			expectedStatus: http.StatusNotFound,
			expectedBody: map[string]interface{}{
				"success": false,
				"error":   "Pricing not found for service: unknown_service",
			},
		},
		{
			name:        "internal error - returns 500 on database error",
			serviceCode: "kyc_verification",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			expectedBody: map[string]interface{}{
				"success": false,
				"error":   "Internal server error",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/pricing/"+tt.serviceCode, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			for key, expectedValue := range tt.expectedBody {
				assert.Equal(t, expectedValue, body[key], "mismatch for key: %s", key)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for ListPricing
func TestPricingHandler_ListPricing(t *testing.T) {
	tests := []struct {
		name           string
		queryParams    string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:        "success - returns all pricing",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				pricing := []*repository.Pricing{createTestPricing()}
				m.On("ListPricing", mock.Anything, false).Return(pricing, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				data := body["data"].(map[string]interface{})
				assert.Equal(t, float64(1), data["total"])
			},
		},
		{
			name:        "success - returns active pricing only",
			queryParams: "?active_only=true",
			setupMock: func(m *MockPricingRepository) {
				pricing := []*repository.Pricing{createTestPricing()}
				m.On("ListPricing", mock.Anything, true).Return(pricing, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
			},
		},
		{
			name:        "success - returns empty list",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				m.On("ListPricing", mock.Anything, false).Return([]*repository.Pricing{}, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				data := body["data"].(map[string]interface{})
				assert.Equal(t, float64(0), data["total"])
			},
		},
		{
			name:        "internal error - database failure",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				m.On("ListPricing", mock.Anything, false).Return(nil, repository.ErrDatabaseError)
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
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/pricing"+tt.queryParams, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for UpdatePricing
func TestPricingHandler_UpdatePricing(t *testing.T) {
	validOperator := "0x1234567890123456789012345678901234567890"
	newPrice := 20.0

	tests := []struct {
		name           string
		serviceCode    string
		requestBody    interface{}
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:        "success - updates pricing",
			serviceCode: "kyc_verification",
			requestBody: map[string]interface{}{
				"price_usd": newPrice,
				"operator":  validOperator,
				"reason":    "Market adjustment",
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePricing", mock.Anything, "kyc_verification", mock.AnythingOfType("*repository.PricingUpdate")).
					Return(nil)
				updatedPricing := createTestPricing()
				updatedPricing.PriceUSD = newPrice
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(updatedPricing, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.Equal(t, "Pricing updated successfully", body["message"])
			},
		},
		{
			name:        "bad request - missing operator",
			serviceCode: "kyc_verification",
			requestBody: map[string]interface{}{
				"price_usd": newPrice,
			},
			setupMock:      func(m *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Invalid request")
			},
		},
		{
			name:        "bad request - invalid operator address",
			serviceCode: "kyc_verification",
			requestBody: map[string]interface{}{
				"price_usd": newPrice,
				"operator":  "invalid-address",
			},
			setupMock:      func(m *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid operator address format", body["error"])
			},
		},
		{
			name:        "not found - unknown service",
			serviceCode: "unknown_service",
			requestBody: map[string]interface{}{
				"price_usd": newPrice,
				"operator":  validOperator,
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePricing", mock.Anything, "unknown_service", mock.AnythingOfType("*repository.PricingUpdate")).
					Return(repository.ErrPricingNotFound)
			},
			expectedStatus: http.StatusNotFound,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Pricing not found")
			},
		},
		{
			name:        "internal error - database failure",
			serviceCode: "kyc_verification",
			requestBody: map[string]interface{}{
				"price_usd": newPrice,
				"operator":  validOperator,
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePricing", mock.Anything, "kyc_verification", mock.AnythingOfType("*repository.PricingUpdate")).
					Return(repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Failed to update pricing", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			reqBody, _ := json.Marshal(tt.requestBody)
			req, _ := http.NewRequest("PUT", "/api/v1/pricing/"+tt.serviceCode, bytes.NewBuffer(reqBody))
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

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for GetKYCPricing
func TestPricingHandler_GetKYCPricing(t *testing.T) {
	tests := []struct {
		name           string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name: "success - returns KYC pricing with payment options",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricing(), nil)
				methods := []*repository.PaymentMethod{
					createTestPaymentMethod("stripe"),
					createTestPaymentMethod("eth"),
					createTestPaymentMethod("nexus"),
				}
				m.On("ListPaymentMethods", mock.Anything, true).Return(methods, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				data := body["data"].(map[string]interface{})
				assert.Equal(t, "kyc_verification", data["service"])
				assert.NotNil(t, data["payment_options"])
			},
		},
		{
			name: "internal error - pricing fetch fails",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Failed to retrieve KYC pricing", body["error"])
			},
		},
		{
			name: "internal error - payment methods fetch fails",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricing", mock.Anything, "kyc_verification").
					Return(createTestPricing(), nil)
				m.On("ListPaymentMethods", mock.Anything, true).
					Return(nil, repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Failed to retrieve payment methods", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/pricing/kyc", nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for GetPricingHistory
func TestPricingHandler_GetPricingHistory(t *testing.T) {
	tests := []struct {
		name           string
		serviceCode    string
		queryParams    string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:        "success - returns pricing history",
			serviceCode: "kyc_verification",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				history := []*repository.PricingHistoryEntry{
					{
						ID:               "hist-001",
						PricingID:        "price-001",
						OldPriceUSD:      floatPtr(10.0),
						NewPriceUSD:      floatPtr(15.0),
						ChangedBy:        "0x1234567890123456789012345678901234567890",
						ChangedAt:        time.Now(),
						ChangeReason:     "Market adjustment",
					},
				}
				m.On("GetPricingHistory", mock.Anything, "kyc_verification", 20).Return(history, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				data := body["data"].(map[string]interface{})
				assert.Equal(t, "kyc_verification", data["service_code"])
				assert.Equal(t, float64(1), data["total"])
			},
		},
		{
			name:        "success - custom limit",
			serviceCode: "kyc_verification",
			queryParams: "?limit=10",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricingHistory", mock.Anything, "kyc_verification", 10).
					Return([]*repository.PricingHistoryEntry{}, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
			},
		},
		{
			name:        "success - limit clamped to max 100",
			serviceCode: "kyc_verification",
			queryParams: "?limit=500",
			setupMock: func(m *MockPricingRepository) {
				// Limit should be clamped to default 20 when invalid
				m.On("GetPricingHistory", mock.Anything, "kyc_verification", 20).
					Return([]*repository.PricingHistoryEntry{}, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
			},
		},
		{
			name:        "internal error - database failure",
			serviceCode: "kyc_verification",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPricingHistory", mock.Anything, "kyc_verification", 20).
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
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/pricing/"+tt.serviceCode+"/history"+tt.queryParams, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for ListPaymentMethods
func TestPricingHandler_ListPaymentMethods(t *testing.T) {
	tests := []struct {
		name           string
		queryParams    string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:        "success - returns active methods (default)",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				methods := []*repository.PaymentMethod{
					createTestPaymentMethod("stripe"),
					createTestPaymentMethod("eth"),
				}
				m.On("ListPaymentMethods", mock.Anything, true).Return(methods, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				data := body["data"].(map[string]interface{})
				assert.Equal(t, float64(2), data["total"])
			},
		},
		{
			name:        "success - returns all methods",
			queryParams: "?active_only=false",
			setupMock: func(m *MockPricingRepository) {
				methods := []*repository.PaymentMethod{
					createTestPaymentMethod("stripe"),
				}
				m.On("ListPaymentMethods", mock.Anything, false).Return(methods, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
			},
		},
		{
			name:        "internal error - database failure",
			queryParams: "",
			setupMock: func(m *MockPricingRepository) {
				m.On("ListPaymentMethods", mock.Anything, true).
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
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/payment-methods"+tt.queryParams, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for GetPaymentMethod
func TestPricingHandler_GetPaymentMethod(t *testing.T) {
	tests := []struct {
		name           string
		methodCode     string
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:       "success - returns payment method",
			methodCode: "stripe",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPaymentMethod", mock.Anything, "stripe").
					Return(createTestPaymentMethod("stripe"), nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.NotNil(t, body["data"])
			},
		},
		{
			name:       "not found - unknown method",
			methodCode: "unknown",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPaymentMethod", mock.Anything, "unknown").
					Return(nil, repository.ErrPaymentMethodNotFound)
			},
			expectedStatus: http.StatusNotFound,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Payment method not found")
			},
		},
		{
			name:       "internal error - database failure",
			methodCode: "stripe",
			setupMock: func(m *MockPricingRepository) {
				m.On("GetPaymentMethod", mock.Anything, "stripe").
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
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			req, _ := http.NewRequest("GET", "/api/v1/payment-methods/"+tt.methodCode, nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			if tt.checkBody != nil {
				tt.checkBody(t, body)
			}

			mockRepo.AssertExpectations(t)
		})
	}
}

// Tests for UpdatePaymentMethod
func TestPricingHandler_UpdatePaymentMethod(t *testing.T) {
	validOperator := "0x1234567890123456789012345678901234567890"

	tests := []struct {
		name           string
		methodCode     string
		requestBody    interface{}
		setupMock      func(*MockPricingRepository)
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:       "success - updates payment method",
			methodCode: "stripe",
			requestBody: map[string]interface{}{
				"fee_percent": 3.5,
				"operator":    validOperator,
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePaymentMethod", mock.Anything, "stripe", mock.AnythingOfType("*repository.PaymentMethodUpdate")).
					Return(nil)
				updated := createTestPaymentMethod("stripe")
				updated.FeePercent = 3.5
				m.On("GetPaymentMethod", mock.Anything, "stripe").Return(updated, nil)
			},
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["success"].(bool))
				assert.Equal(t, "Payment method updated successfully", body["message"])
			},
		},
		{
			name:       "bad request - missing operator",
			methodCode: "stripe",
			requestBody: map[string]interface{}{
				"fee_percent": 3.5,
			},
			setupMock:      func(m *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
			},
		},
		{
			name:       "bad request - invalid operator address",
			methodCode: "stripe",
			requestBody: map[string]interface{}{
				"fee_percent": 3.5,
				"operator":    "invalid",
			},
			setupMock:      func(m *MockPricingRepository) {},
			expectedStatus: http.StatusBadRequest,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Invalid operator address format", body["error"])
			},
		},
		{
			name:       "not found - unknown method",
			methodCode: "unknown",
			requestBody: map[string]interface{}{
				"fee_percent": 3.5,
				"operator":    validOperator,
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePaymentMethod", mock.Anything, "unknown", mock.AnythingOfType("*repository.PaymentMethodUpdate")).
					Return(repository.ErrPaymentMethodNotFound)
			},
			expectedStatus: http.StatusNotFound,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Contains(t, body["error"].(string), "Payment method not found")
			},
		},
		{
			name:       "internal error - database failure",
			methodCode: "stripe",
			requestBody: map[string]interface{}{
				"fee_percent": 3.5,
				"operator":    validOperator,
			},
			setupMock: func(m *MockPricingRepository) {
				m.On("UpdatePaymentMethod", mock.Anything, "stripe", mock.AnythingOfType("*repository.PaymentMethodUpdate")).
					Return(repository.ErrDatabaseError)
			},
			expectedStatus: http.StatusInternalServerError,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.False(t, body["success"].(bool))
				assert.Equal(t, "Failed to update payment method", body["error"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mockRepo := new(MockPricingRepository)
			tt.setupMock(mockRepo)

			logger := zap.NewNop()
			handler := handlers.NewPricingHandler(mockRepo, logger)
			router := setupPricingTestRouter(handler)

			reqBody, _ := json.Marshal(tt.requestBody)
			req, _ := http.NewRequest("PUT", "/api/v1/payment-methods/"+tt.methodCode, bytes.NewBuffer(reqBody))
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

			mockRepo.AssertExpectations(t)
		})
	}
}

// Helper function to create float pointers
func floatPtr(f float64) *float64 {
	return &f
}
