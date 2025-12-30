package handlers

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// HealthHandler handles health and readiness checks
type HealthHandler struct {
	logger    *zap.Logger
	startTime time.Time
	mu        sync.RWMutex
	ready     bool
	checks    map[string]HealthCheck
}

// HealthCheck represents a single health check function
type HealthCheck func() error

// HealthResponse represents the health check response
type HealthResponse struct {
	Status    string            `json:"status"`
	Timestamp string            `json:"timestamp"`
	Uptime    string            `json:"uptime"`
	Version   string            `json:"version"`
	Checks    map[string]string `json:"checks,omitempty"`
}

// ReadyResponse represents the readiness check response
type ReadyResponse struct {
	Ready     bool              `json:"ready"`
	Timestamp string            `json:"timestamp"`
	Checks    map[string]string `json:"checks,omitempty"`
}

// NewHealthHandler creates a new health handler
func NewHealthHandler(logger *zap.Logger) *HealthHandler {
	return &HealthHandler{
		logger:    logger,
		startTime: time.Now(),
		ready:     false,
		checks:    make(map[string]HealthCheck),
	}
}

// RegisterCheck registers a named health check
func (h *HealthHandler) RegisterCheck(name string, check HealthCheck) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.checks[name] = check
}

// SetReady sets the readiness state
func (h *HealthHandler) SetReady(ready bool) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.ready = ready
	h.logger.Info("readiness state changed", zap.Bool("ready", ready))
}

// Health handles the /health endpoint
// @Summary Health check
// @Description Returns the health status of the service
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Router /health [get]
func (h *HealthHandler) Health(c *gin.Context) {
	uptime := time.Since(h.startTime)

	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Uptime:    uptime.String(),
		Version:   "1.0.0", // TODO: inject from build
	}

	h.logger.Debug("health check requested",
		zap.String("status", response.Status),
		zap.Duration("uptime", uptime),
	)

	c.JSON(http.StatusOK, response)
}

// Ready handles the /ready endpoint
// @Summary Readiness check
// @Description Returns whether the service is ready to accept traffic
// @Tags health
// @Produce json
// @Success 200 {object} ReadyResponse
// @Failure 503 {object} ReadyResponse
// @Router /ready [get]
func (h *HealthHandler) Ready(c *gin.Context) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	checksStatus := make(map[string]string)
	allPassed := true

	// Run all registered health checks
	for name, check := range h.checks {
		if err := check(); err != nil {
			checksStatus[name] = err.Error()
			allPassed = false
			h.logger.Warn("health check failed",
				zap.String("check", name),
				zap.Error(err),
			)
		} else {
			checksStatus[name] = "ok"
		}
	}

	response := ReadyResponse{
		Ready:     h.ready && allPassed,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Checks:    checksStatus,
	}

	if !response.Ready {
		h.logger.Warn("service not ready",
			zap.Bool("ready_flag", h.ready),
			zap.Bool("checks_passed", allPassed),
		)
		c.JSON(http.StatusServiceUnavailable, response)
		return
	}

	h.logger.Debug("readiness check passed")
	c.JSON(http.StatusOK, response)
}

// Live handles the /live endpoint (Kubernetes liveness probe)
// @Summary Liveness check
// @Description Returns whether the service is alive
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /live [get]
func (h *HealthHandler) Live(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"status":    "alive",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}
