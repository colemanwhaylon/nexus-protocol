package middleware

import (
	"net/http"
	"strconv"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// RateLimiter implements a token bucket rate limiter per IP
type RateLimiter struct {
	mu              sync.RWMutex
	clients         map[string]*clientBucket
	requestsPerMin  int
	burstSize       int
	cleanupInterval time.Duration
	logger          *zap.Logger
	stopCleanup     chan struct{}
}

// clientBucket tracks rate limiting for a single client
type clientBucket struct {
	tokens    float64
	lastCheck time.Time
	mu        sync.Mutex
}

// RateLimitConfig holds rate limiter configuration
type RateLimitConfig struct {
	RequestsPerMin  int
	BurstSize       int
	CleanupInterval time.Duration
}

// DefaultRateLimitConfig returns default rate limit configuration
func DefaultRateLimitConfig() RateLimitConfig {
	return RateLimitConfig{
		RequestsPerMin:  100,
		BurstSize:       10,
		CleanupInterval: time.Minute,
	}
}

// NewRateLimiter creates a new rate limiter
func NewRateLimiter(cfg RateLimitConfig, logger *zap.Logger) *RateLimiter {
	rl := &RateLimiter{
		clients:         make(map[string]*clientBucket),
		requestsPerMin:  cfg.RequestsPerMin,
		burstSize:       cfg.BurstSize,
		cleanupInterval: cfg.CleanupInterval,
		logger:          logger,
		stopCleanup:     make(chan struct{}),
	}

	// Start background cleanup goroutine
	go rl.cleanup()

	return rl
}

// cleanup periodically removes stale client buckets
func (rl *RateLimiter) cleanup() {
	ticker := time.NewTicker(rl.cleanupInterval)
	defer ticker.Stop()

	for {
		select {
		case <-ticker.C:
			rl.mu.Lock()
			now := time.Now()
			staleThreshold := 5 * time.Minute

			for ip, bucket := range rl.clients {
				bucket.mu.Lock()
				if now.Sub(bucket.lastCheck) > staleThreshold {
					delete(rl.clients, ip)
					rl.logger.Debug("removed stale rate limit bucket",
						zap.String("ip", ip),
					)
				}
				bucket.mu.Unlock()
			}
			rl.mu.Unlock()

		case <-rl.stopCleanup:
			return
		}
	}
}

// Stop stops the background cleanup goroutine
func (rl *RateLimiter) Stop() {
	close(rl.stopCleanup)
}

// getClientBucket gets or creates a bucket for the given IP
func (rl *RateLimiter) getClientBucket(ip string) *clientBucket {
	rl.mu.RLock()
	bucket, exists := rl.clients[ip]
	rl.mu.RUnlock()

	if exists {
		return bucket
	}

	rl.mu.Lock()
	defer rl.mu.Unlock()

	// Double-check after acquiring write lock
	if bucket, exists = rl.clients[ip]; exists {
		return bucket
	}

	bucket = &clientBucket{
		tokens:    float64(rl.burstSize),
		lastCheck: time.Now(),
	}
	rl.clients[ip] = bucket

	return bucket
}

// allow checks if a request from the given IP should be allowed
func (rl *RateLimiter) allow(ip string) (bool, int, time.Time) {
	bucket := rl.getClientBucket(ip)

	bucket.mu.Lock()
	defer bucket.mu.Unlock()

	now := time.Now()
	elapsed := now.Sub(bucket.lastCheck)
	bucket.lastCheck = now

	// Refill tokens based on elapsed time
	// tokens per second = requestsPerMin / 60
	refillRate := float64(rl.requestsPerMin) / 60.0
	bucket.tokens += elapsed.Seconds() * refillRate

	// Cap tokens at burst size
	if bucket.tokens > float64(rl.burstSize) {
		bucket.tokens = float64(rl.burstSize)
	}

	// Check if we have tokens available
	if bucket.tokens < 1 {
		// Calculate when a token will be available
		tokensNeeded := 1 - bucket.tokens
		waitTime := time.Duration(tokensNeeded/refillRate) * time.Second
		resetTime := now.Add(waitTime)

		return false, int(bucket.tokens), resetTime
	}

	// Consume a token
	bucket.tokens--

	return true, int(bucket.tokens), time.Time{}
}

// Middleware returns the rate limiting middleware
func (rl *RateLimiter) Middleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		// Get client IP
		ip := c.ClientIP()

		// Check rate limit
		allowed, remaining, resetTime := rl.allow(ip)

		// Set rate limit headers
		c.Header("X-RateLimit-Limit", strconv.Itoa(rl.requestsPerMin))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))

		if !allowed {
			c.Header("X-RateLimit-Reset", strconv.FormatInt(resetTime.Unix(), 10))
			c.Header("Retry-After", strconv.Itoa(int(time.Until(resetTime).Seconds())+1))

			rl.logger.Warn("rate limit exceeded",
				zap.String("ip", ip),
				zap.String("path", c.Request.URL.Path),
				zap.Time("reset_time", resetTime),
			)

			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{
				"error":       "rate limit exceeded",
				"retry_after": int(time.Until(resetTime).Seconds()) + 1,
				"limit":       rl.requestsPerMin,
			})
			return
		}

		c.Next()
	}
}

// RateLimit creates a rate limiting middleware with default configuration
func RateLimit(logger *zap.Logger) gin.HandlerFunc {
	limiter := NewRateLimiter(DefaultRateLimitConfig(), logger)
	return limiter.Middleware()
}
