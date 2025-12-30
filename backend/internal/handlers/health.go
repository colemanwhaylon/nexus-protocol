package handlers

import (
	"net/http"
	"runtime"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// HealthHandler handles health check endpoints
type HealthHandler struct {
	logger    *zap.Logger
	startTime time.Time
	version   string
	commit    string
	buildDate string
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Status      string            `json:"status"`
	Timestamp   string            `json:"timestamp"`
	Version     string            `json:"version,omitempty"`
	Commit      string            `json:"commit,omitempty"`
	BuildDate   string            `json:"build_date,omitempty"`
	Uptime      string            `json:"uptime,omitempty"`
	Checks      map[string]Check  `json:"checks,omitempty"`
}

// Check represents an individual health check result
type Check struct {
	Status  string `json:"status"`
	Message string `json:"message,omitempty"`
	Latency string `json:"latency,omitempty"`
}

// ReadinessResponse represents the readiness check response
type ReadinessResponse struct {
	Ready     bool              `json:"ready"`
	Timestamp string            `json:"timestamp"`
	Checks    map[string]Check  `json:"checks,omitempty"`
}

// MetricsResponse represents basic metrics
type MetricsResponse struct {
	Timestamp     string `json:"timestamp"`
	Uptime        string `json:"uptime"`
	NumGoroutines int    `json:"num_goroutines"`
	NumCPU        int    `json:"num_cpu"`
	MemAlloc      uint64 `json:"memory_alloc_mb"`
	MemSys        uint64 `json:"memory_sys_mb"`
	NumGC         uint32 `json:"num_gc"`
}

// NewHealthHandler creates a new health handler
func NewHealthHandler(logger *zap.Logger, version, commit, buildDate string) *HealthHandler {
	return &HealthHandler{
		logger:    logger,
		startTime: time.Now(),
		version:   version,
		commit:    commit,
		buildDate: buildDate,
	}
}

// Health handles GET /health
// @Summary Health check
// @Description Returns the health status of the API
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Router /health [get]
func (h *HealthHandler) Health(c *gin.Context) {
	response := HealthResponse{
		Status:    "healthy",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   h.version,
		Commit:    h.commit,
		BuildDate: h.buildDate,
		Uptime:    time.Since(h.startTime).Round(time.Second).String(),
	}

	c.JSON(http.StatusOK, response)
}

// HealthDetailed handles GET /health/detailed
// @Summary Detailed health check
// @Description Returns detailed health status including dependency checks
// @Tags health
// @Produce json
// @Success 200 {object} HealthResponse
// @Failure 503 {object} HealthResponse
// @Router /health/detailed [get]
func (h *HealthHandler) HealthDetailed(c *gin.Context) {
	checks := make(map[string]Check)
	allHealthy := true

	// Check database
	dbCheck := h.checkDatabase()
	checks["database"] = dbCheck
	if dbCheck.Status != "healthy" {
		allHealthy = false
	}

	// Check cache
	cacheCheck := h.checkCache()
	checks["cache"] = cacheCheck
	if cacheCheck.Status != "healthy" {
		allHealthy = false
	}

	// Check blockchain connection (if configured)
	blockchainCheck := h.checkBlockchain()
	checks["blockchain"] = blockchainCheck
	// Blockchain is optional, don't fail health check

	status := "healthy"
	httpStatus := http.StatusOK
	if !allHealthy {
		status = "degraded"
		httpStatus = http.StatusServiceUnavailable
	}

	response := HealthResponse{
		Status:    status,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Version:   h.version,
		Commit:    h.commit,
		BuildDate: h.buildDate,
		Uptime:    time.Since(h.startTime).Round(time.Second).String(),
		Checks:    checks,
	}

	c.JSON(httpStatus, response)
}

// Ready handles GET /ready
// @Summary Readiness check
// @Description Returns whether the API is ready to serve traffic
// @Tags health
// @Produce json
// @Success 200 {object} ReadinessResponse
// @Failure 503 {object} ReadinessResponse
// @Router /ready [get]
func (h *HealthHandler) Ready(c *gin.Context) {
	checks := make(map[string]Check)
	ready := true

	// For readiness, we check if we can serve requests
	dbCheck := h.checkDatabase()
	checks["database"] = dbCheck
	if dbCheck.Status != "healthy" {
		ready = false
	}

	httpStatus := http.StatusOK
	if !ready {
		httpStatus = http.StatusServiceUnavailable
	}

	response := ReadinessResponse{
		Ready:     ready,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Checks:    checks,
	}

	c.JSON(httpStatus, response)
}

// Live handles GET /live
// @Summary Liveness check
// @Description Returns whether the API is alive (for Kubernetes liveness probes)
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /live [get]
func (h *HealthHandler) Live(c *gin.Context) {
	// Liveness just checks if the process is running
	c.JSON(http.StatusOK, gin.H{
		"status":    "alive",
		"timestamp": time.Now().UTC().Format(time.RFC3339),
	})
}

// Metrics handles GET /metrics
// @Summary Basic metrics
// @Description Returns basic runtime metrics (for more detailed metrics, use Prometheus endpoint)
// @Tags health
// @Produce json
// @Success 200 {object} MetricsResponse
// @Router /metrics [get]
func (h *HealthHandler) Metrics(c *gin.Context) {
	var m runtime.MemStats
	runtime.ReadMemStats(&m)

	response := MetricsResponse{
		Timestamp:     time.Now().UTC().Format(time.RFC3339),
		Uptime:        time.Since(h.startTime).Round(time.Second).String(),
		NumGoroutines: runtime.NumGoroutine(),
		NumCPU:        runtime.NumCPU(),
		MemAlloc:      m.Alloc / 1024 / 1024,
		MemSys:        m.Sys / 1024 / 1024,
		NumGC:         m.NumGC,
	}

	c.JSON(http.StatusOK, response)
}

// Version handles GET /version
// @Summary Version information
// @Description Returns the API version and build information
// @Tags health
// @Produce json
// @Success 200 {object} map[string]string
// @Router /version [get]
func (h *HealthHandler) Version(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{
		"version":    h.version,
		"commit":     h.commit,
		"build_date": h.buildDate,
		"go_version": runtime.Version(),
		"os":         runtime.GOOS,
		"arch":       runtime.GOARCH,
	})
}

// checkDatabase checks database connectivity
func (h *HealthHandler) checkDatabase() Check {
	start := time.Now()

	// In production, this would ping the actual database
	// For demo with in-memory storage, always healthy
	latency := time.Since(start)

	return Check{
		Status:  "healthy",
		Message: "Database connection OK",
		Latency: latency.String(),
	}
}

// checkCache checks cache connectivity
func (h *HealthHandler) checkCache() Check {
	start := time.Now()

	// In production, this would ping Redis
	// For demo with in-memory cache, always healthy
	latency := time.Since(start)

	return Check{
		Status:  "healthy",
		Message: "Cache connection OK",
		Latency: latency.String(),
	}
}

// checkBlockchain checks blockchain RPC connectivity
func (h *HealthHandler) checkBlockchain() Check {
	start := time.Now()

	// In production, this would check RPC connection
	// For demo, return optional/unconfigured status
	latency := time.Since(start)

	return Check{
		Status:  "healthy",
		Message: "Blockchain RPC not configured (optional)",
		Latency: latency.String(),
	}
}

// Ping handles GET /ping
// @Summary Ping
// @Description Simple ping endpoint for load balancer health checks
// @Tags health
// @Produce plain
// @Success 200 {string} string "pong"
// @Router /ping [get]
func (h *HealthHandler) Ping(c *gin.Context) {
	c.String(http.StatusOK, "pong")
}
