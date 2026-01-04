package handlers_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/handlers"
)

// Helper functions for health tests
func setupHealthTestRouter(handler *handlers.HealthHandler) *gin.Engine {
	gin.SetMode(gin.TestMode)
	router := gin.New()

	router.GET("/health", handler.Health)
	router.GET("/health/detailed", handler.HealthDetailed)
	router.GET("/ready", handler.Ready)
	router.GET("/live", handler.Live)
	router.GET("/metrics", handler.Metrics)
	router.GET("/version", handler.Version)
	router.GET("/ping", handler.Ping)

	return router
}

func createTestHealthHandler() *handlers.HealthHandler {
	logger := zap.NewNop()
	return handlers.NewHealthHandler(logger, "1.0.0", "abc123", "2024-01-15")
}

// Tests for Health endpoint
func TestHealthHandler_Health(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns healthy status",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.Equal(t, "healthy", body["status"])
				assert.NotEmpty(t, body["timestamp"])
				assert.Equal(t, "1.0.0", body["version"])
				assert.Equal(t, "abc123", body["commit"])
				assert.Equal(t, "2024-01-15", body["build_date"])
				assert.NotEmpty(t, body["uptime"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/health", nil)
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

// Tests for HealthDetailed endpoint
func TestHealthHandler_HealthDetailed(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns detailed health with checks",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.Equal(t, "healthy", body["status"])
				assert.NotEmpty(t, body["timestamp"])
				assert.Equal(t, "1.0.0", body["version"])
				assert.NotEmpty(t, body["uptime"])

				// Check that checks are present
				checks, ok := body["checks"].(map[string]interface{})
				assert.True(t, ok, "checks should be a map")

				// Verify database check
				dbCheck, ok := checks["database"].(map[string]interface{})
				assert.True(t, ok, "database check should be present")
				assert.Equal(t, "healthy", dbCheck["status"])

				// Verify cache check
				cacheCheck, ok := checks["cache"].(map[string]interface{})
				assert.True(t, ok, "cache check should be present")
				assert.Equal(t, "healthy", cacheCheck["status"])

				// Verify blockchain check
				blockchainCheck, ok := checks["blockchain"].(map[string]interface{})
				assert.True(t, ok, "blockchain check should be present")
				assert.NotEmpty(t, blockchainCheck["status"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/health/detailed", nil)
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

// Tests for Ready endpoint
func TestHealthHandler_Ready(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns ready status",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.True(t, body["ready"].(bool))
				assert.NotEmpty(t, body["timestamp"])

				// Verify checks are present
				checks, ok := body["checks"].(map[string]interface{})
				assert.True(t, ok, "checks should be a map")
				assert.NotEmpty(t, checks)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/ready", nil)
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

// Tests for Live endpoint
func TestHealthHandler_Live(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns alive status",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.Equal(t, "alive", body["status"])
				assert.NotEmpty(t, body["timestamp"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/live", nil)
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

// Tests for Metrics endpoint
func TestHealthHandler_Metrics(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns runtime metrics",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.NotEmpty(t, body["timestamp"])
				assert.NotEmpty(t, body["uptime"])

				// Check numeric fields exist and are valid
				numGoroutines := body["num_goroutines"].(float64)
				assert.GreaterOrEqual(t, numGoroutines, float64(1))

				numCPU := body["num_cpu"].(float64)
				assert.GreaterOrEqual(t, numCPU, float64(1))

				// Memory stats should be present
				assert.NotNil(t, body["memory_alloc_mb"])
				assert.NotNil(t, body["memory_sys_mb"])
				assert.NotNil(t, body["num_gc"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/metrics", nil)
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

// Tests for Version endpoint
func TestHealthHandler_Version(t *testing.T) {
	tests := []struct {
		name           string
		version        string
		commit         string
		buildDate      string
		expectedStatus int
		checkBody      func(*testing.T, map[string]interface{})
	}{
		{
			name:           "success - returns version info",
			version:        "1.0.0",
			commit:         "abc123def",
			buildDate:      "2024-01-15T10:00:00Z",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.Equal(t, "1.0.0", body["version"])
				assert.Equal(t, "abc123def", body["commit"])
				assert.Equal(t, "2024-01-15T10:00:00Z", body["build_date"])
				assert.NotEmpty(t, body["go_version"])
				assert.NotEmpty(t, body["os"])
				assert.NotEmpty(t, body["arch"])
			},
		},
		{
			name:           "success - with development version",
			version:        "dev",
			commit:         "dirty",
			buildDate:      "unknown",
			expectedStatus: http.StatusOK,
			checkBody: func(t *testing.T, body map[string]interface{}) {
				assert.Equal(t, "dev", body["version"])
				assert.Equal(t, "dirty", body["commit"])
				assert.Equal(t, "unknown", body["build_date"])
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := zap.NewNop()
			handler := handlers.NewHealthHandler(logger, tt.version, tt.commit, tt.buildDate)
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/version", nil)
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

// Tests for Ping endpoint
func TestHealthHandler_Ping(t *testing.T) {
	tests := []struct {
		name           string
		expectedStatus int
		expectedBody   string
	}{
		{
			name:           "success - returns pong",
			expectedStatus: http.StatusOK,
			expectedBody:   "pong",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/ping", nil)
			resp := httptest.NewRecorder()

			router.ServeHTTP(resp, req)

			assert.Equal(t, tt.expectedStatus, resp.Code)
			assert.Equal(t, tt.expectedBody, resp.Body.String())
		})
	}
}

// Tests for uptime tracking
func TestHealthHandler_UptimeTracking(t *testing.T) {
	t.Run("uptime increases over time", func(t *testing.T) {
		handler := createTestHealthHandler()
		router := setupHealthTestRouter(handler)

		// First request
		req1, _ := http.NewRequest("GET", "/health", nil)
		resp1 := httptest.NewRecorder()
		router.ServeHTTP(resp1, req1)

		var body1 map[string]interface{}
		_ = json.Unmarshal(resp1.Body.Bytes(), &body1)
		uptime1 := body1["uptime"].(string)

		// Wait a bit
		time.Sleep(10 * time.Millisecond)

		// Second request
		req2, _ := http.NewRequest("GET", "/health", nil)
		resp2 := httptest.NewRecorder()
		router.ServeHTTP(resp2, req2)

		var body2 map[string]interface{}
		_ = json.Unmarshal(resp2.Body.Bytes(), &body2)
		uptime2 := body2["uptime"].(string)

		// Both should have valid uptime strings
		assert.NotEmpty(t, uptime1)
		assert.NotEmpty(t, uptime2)
	})
}

// Tests for timestamp format
func TestHealthHandler_TimestampFormat(t *testing.T) {
	endpoints := []string{"/health", "/health/detailed", "/ready", "/live", "/metrics"}

	for _, endpoint := range endpoints {
		t.Run("timestamp format for "+endpoint, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", endpoint, nil)
			resp := httptest.NewRecorder()
			router.ServeHTTP(resp, req)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			timestamp, ok := body["timestamp"].(string)
			require.True(t, ok, "timestamp should be a string")

			// Should be RFC3339 format
			_, err = time.Parse(time.RFC3339, timestamp)
			assert.NoError(t, err, "timestamp should be in RFC3339 format")
		})
	}
}

// Tests for content type
func TestHealthHandler_ContentType(t *testing.T) {
	endpoints := []struct {
		path        string
		contentType string
	}{
		{"/health", "application/json"},
		{"/health/detailed", "application/json"},
		{"/ready", "application/json"},
		{"/live", "application/json"},
		{"/metrics", "application/json"},
		{"/version", "application/json"},
		{"/ping", "text/plain"},
	}

	for _, ep := range endpoints {
		t.Run("content type for "+ep.path, func(t *testing.T) {
			handler := createTestHealthHandler()
			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", ep.path, nil)
			resp := httptest.NewRecorder()
			router.ServeHTTP(resp, req)

			contentType := resp.Header().Get("Content-Type")
			assert.Contains(t, contentType, ep.contentType)
		})
	}
}

// Tests for concurrent requests
func TestHealthHandler_ConcurrentRequests(t *testing.T) {
	handler := createTestHealthHandler()
	router := setupHealthTestRouter(handler)

	const numRequests = 50
	results := make(chan int, numRequests)

	for i := 0; i < numRequests; i++ {
		go func() {
			req, _ := http.NewRequest("GET", "/health", nil)
			resp := httptest.NewRecorder()
			router.ServeHTTP(resp, req)
			results <- resp.Code
		}()
	}

	for i := 0; i < numRequests; i++ {
		code := <-results
		assert.Equal(t, http.StatusOK, code)
	}
}

// Tests for handler initialization
func TestHealthHandler_Initialization(t *testing.T) {
	tests := []struct {
		name      string
		version   string
		commit    string
		buildDate string
	}{
		{
			name:      "with all fields populated",
			version:   "2.0.0",
			commit:    "1234567890abcdef",
			buildDate: "2024-06-01",
		},
		{
			name:      "with empty fields",
			version:   "",
			commit:    "",
			buildDate: "",
		},
		{
			name:      "with special characters",
			version:   "v1.0.0-beta+build.123",
			commit:    "abc123",
			buildDate: "2024-01-01T00:00:00Z",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			logger := zap.NewNop()
			handler := handlers.NewHealthHandler(logger, tt.version, tt.commit, tt.buildDate)
			assert.NotNil(t, handler)

			router := setupHealthTestRouter(handler)

			req, _ := http.NewRequest("GET", "/version", nil)
			resp := httptest.NewRecorder()
			router.ServeHTTP(resp, req)

			assert.Equal(t, http.StatusOK, resp.Code)

			var body map[string]interface{}
			err := json.Unmarshal(resp.Body.Bytes(), &body)
			require.NoError(t, err)

			assert.Equal(t, tt.version, body["version"])
			assert.Equal(t, tt.commit, body["commit"])
			assert.Equal(t, tt.buildDate, body["build_date"])
		})
	}
}

// Benchmark tests
func BenchmarkHealthHandler_Health(b *testing.B) {
	handler := createTestHealthHandler()
	router := setupHealthTestRouter(handler)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req, _ := http.NewRequest("GET", "/health", nil)
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)
	}
}

func BenchmarkHealthHandler_HealthDetailed(b *testing.B) {
	handler := createTestHealthHandler()
	router := setupHealthTestRouter(handler)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req, _ := http.NewRequest("GET", "/health/detailed", nil)
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)
	}
}

func BenchmarkHealthHandler_Metrics(b *testing.B) {
	handler := createTestHealthHandler()
	router := setupHealthTestRouter(handler)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req, _ := http.NewRequest("GET", "/metrics", nil)
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)
	}
}

func BenchmarkHealthHandler_Ping(b *testing.B) {
	handler := createTestHealthHandler()
	router := setupHealthTestRouter(handler)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		req, _ := http.NewRequest("GET", "/ping", nil)
		resp := httptest.NewRecorder()
		router.ServeHTTP(resp, req)
	}
}
