// Package main is the entry point for the Nexus Protocol backend server
package main

import (
	"context"
	"database/sql"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/handlers"
	"github.com/colemanwhaylon/nexus-protocol/backend/internal/storage/postgres"
)

// Build variables (set via ldflags)
var (
	version   = "dev"
	commit    = "unknown"
	buildDate = "unknown"
)

// Config holds the application configuration
type Config struct {
	Port              string
	DatabaseURL       string
	StripeSecretKey   string
	StripeWebhookKey  string
	SumsubAppToken    string
	SumsubSecretKey   string
	RelayerPrivateKey string
	ForwarderAddress  string
	RPCURL            string
	ChainID           int64
	LogLevel          string
	GinMode           string
}

func main() {
	// Load configuration
	cfg := loadConfig()

	// Initialize logger
	logger := initLogger(cfg.LogLevel)
	defer logger.Sync()

	logger.Info("starting nexus-protocol backend",
		zap.String("version", version),
		zap.String("commit", commit),
		zap.String("build_date", buildDate),
	)

	// Set Gin mode
	if cfg.GinMode != "" {
		gin.SetMode(cfg.GinMode)
	}

	// Connect to database
	db, err := sql.Open("postgres", cfg.DatabaseURL)
	if err != nil {
		logger.Fatal("failed to open database connection", zap.Error(err))
	}
	defer db.Close()

	// Configure connection pool
	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)
	db.SetConnMaxLifetime(5 * time.Minute)

	// Verify database connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := db.PingContext(ctx); err != nil {
		logger.Fatal("failed to connect to database", zap.Error(err))
	}
	logger.Info("connected to database")

	// Create repositories (DEPENDENCY INJECTION)
	pricingRepo := postgres.NewPostgresPricingRepo(db)
	paymentRepo := postgres.NewPostgresPaymentRepo(db)
	relayerRepo := postgres.NewPostgresRelayerRepo(db)

	// Create handlers with injected dependencies
	healthHandler := handlers.NewHealthHandler(logger, version, commit, buildDate)
	pricingHandler := handlers.NewPricingHandler(pricingRepo, logger)
	paymentHandler := handlers.NewPaymentHandler(paymentRepo, pricingRepo, logger)
	sumsubHandler := handlers.NewSumsubHandler(paymentRepo, pricingRepo, logger)
	relayerHandler, err := handlers.NewRelayerHandler(relayerRepo, logger)
	if err != nil {
		// Relayer is optional in dev mode - warn but continue
		logger.Warn("relayer handler disabled", zap.Error(err))
		relayerHandler = nil
	}

	// Setup router
	router := gin.New()
	router.Use(gin.Recovery())
	router.Use(loggerMiddleware(logger))
	router.Use(corsMiddleware())

	// Health check routes (no auth required)
	router.GET("/health", healthHandler.Health)
	router.GET("/health/detailed", healthHandler.HealthDetailed)
	router.GET("/ready", healthHandler.Ready)
	router.GET("/live", healthHandler.Live)
	router.GET("/ping", healthHandler.Ping)
	router.GET("/version", healthHandler.Version)
	router.GET("/metrics", healthHandler.Metrics)

	// API v1 routes
	api := router.Group("/api/v1")
	{
		// Pricing routes (public read, admin write)
		pricing := api.Group("/pricing")
		{
			pricing.GET("", pricingHandler.ListPricing)
			pricing.GET("/:code", pricingHandler.GetPricing)
			pricing.GET("/:code/history", pricingHandler.GetPricingHistory)
			pricing.PUT("/:code", pricingHandler.UpdatePricing) // TODO: Add admin auth middleware

			// KYC-specific pricing
			pricing.GET("/kyc", pricingHandler.GetKYCPricing)
		}

		// Payment methods routes
		methods := api.Group("/payment-methods")
		{
			methods.GET("", pricingHandler.ListPaymentMethods)
			methods.GET("/:code", pricingHandler.GetPaymentMethod)
			methods.PUT("/:code", pricingHandler.UpdatePaymentMethod) // TODO: Add admin auth middleware
		}

		// Payment routes
		payments := api.Group("/payments")
		{
			payments.POST("/stripe/checkout", paymentHandler.CreateStripeCheckout)
			payments.POST("/stripe/webhook", paymentHandler.HandleStripeWebhook)
			payments.POST("/crypto", paymentHandler.ProcessCryptoPayment)
			payments.GET("/:id", paymentHandler.GetPayment)
			payments.GET("/session/:sessionId", paymentHandler.GetPaymentBySession)
		}

		// KYC/Sumsub routes
		kyc := api.Group("/kyc")
		{
			kyc.POST("/applicant", sumsubHandler.CreateApplicant)
			kyc.GET("/token/:address", sumsubHandler.GetAccessToken)
			kyc.GET("/status/:address", sumsubHandler.GetVerificationStatus)
			kyc.POST("/webhook", sumsubHandler.HandleWebhook)
		}

		// Meta-transaction relayer routes (only if relayer is configured)
		if relayerHandler != nil {
			relay := api.Group("/relay")
			{
				relay.POST("", relayerHandler.Relay)
				relay.GET("/status/:id", relayerHandler.GetStatus)
				relay.GET("/tx/:txHash", relayerHandler.GetByTxHash)
				relay.GET("/nonce/:address", relayerHandler.GetNonce)
				relay.GET("/user/:address", relayerHandler.ListUserMetaTxs)
				relay.GET("/info/relayer", relayerHandler.GetRelayerAddress)
				relay.GET("/info/forwarder", relayerHandler.GetForwarderAddress)
			}
		}
	}

	// Start server with graceful shutdown
	srv := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		logger.Info("server listening", zap.String("port", cfg.Port))
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Fatal("server failed to start", zap.Error(err))
		}
	}()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info("shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel = context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Fatal("server forced to shutdown", zap.Error(err))
	}

	logger.Info("server exited gracefully")
}

// loadConfig loads configuration from environment variables
func loadConfig() *Config {
	return &Config{
		Port:              getEnv("PORT", "8080"),
		DatabaseURL:       getEnv("DATABASE_URL", "postgres://nexus:nexus@localhost:5432/nexus?sslmode=disable"),
		StripeSecretKey:   getEnv("STRIPE_SECRET_KEY", ""),
		StripeWebhookKey:  getEnv("STRIPE_WEBHOOK_SECRET", ""),
		SumsubAppToken:    getEnv("SUMSUB_APP_TOKEN", ""),
		SumsubSecretKey:   getEnv("SUMSUB_SECRET_KEY", ""),
		RelayerPrivateKey: getEnv("RELAYER_PRIVATE_KEY", ""),
		ForwarderAddress:  getEnv("FORWARDER_ADDRESS", ""),
		RPCURL:            getEnv("RPC_URL", "http://localhost:8545"),
		ChainID:           getEnvInt64("CHAIN_ID", 31337),
		LogLevel:          getEnv("LOG_LEVEL", "info"),
		GinMode:           getEnv("GIN_MODE", "release"),
	}
}

// getEnv gets an environment variable with a default value
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

// getEnvInt64 gets an int64 environment variable with a default value
func getEnvInt64(key string, defaultValue int64) int64 {
	if value := os.Getenv(key); value != "" {
		var result int64
		if _, err := fmt.Sscanf(value, "%d", &result); err == nil {
			return result
		}
	}
	return defaultValue
}

// initLogger initializes the zap logger
func initLogger(level string) *zap.Logger {
	var logLevel zapcore.Level
	switch level {
	case "debug":
		logLevel = zapcore.DebugLevel
	case "info":
		logLevel = zapcore.InfoLevel
	case "warn":
		logLevel = zapcore.WarnLevel
	case "error":
		logLevel = zapcore.ErrorLevel
	default:
		logLevel = zapcore.InfoLevel
	}

	config := zap.Config{
		Level:       zap.NewAtomicLevelAt(logLevel),
		Development: level == "debug",
		Encoding:    "json",
		EncoderConfig: zapcore.EncoderConfig{
			TimeKey:        "timestamp",
			LevelKey:       "level",
			NameKey:        "logger",
			CallerKey:      "caller",
			MessageKey:     "message",
			StacktraceKey:  "stacktrace",
			LineEnding:     zapcore.DefaultLineEnding,
			EncodeLevel:    zapcore.LowercaseLevelEncoder,
			EncodeTime:     zapcore.ISO8601TimeEncoder,
			EncodeDuration: zapcore.SecondsDurationEncoder,
			EncodeCaller:   zapcore.ShortCallerEncoder,
		},
		OutputPaths:      []string{"stdout"},
		ErrorOutputPaths: []string{"stderr"},
	}

	logger, err := config.Build()
	if err != nil {
		log.Fatalf("failed to initialize logger: %v", err)
	}

	return logger
}

// loggerMiddleware creates a Gin middleware for logging requests
func loggerMiddleware(logger *zap.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		query := c.Request.URL.RawQuery

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		logger.Info("http request",
			zap.Int("status", status),
			zap.String("method", c.Request.Method),
			zap.String("path", path),
			zap.String("query", query),
			zap.Duration("latency", latency),
			zap.String("ip", c.ClientIP()),
			zap.String("user_agent", c.Request.UserAgent()),
			zap.Int("body_size", c.Writer.Size()),
		)
	}
}

// corsMiddleware creates a CORS middleware
func corsMiddleware() gin.HandlerFunc {
	return func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, Content-Type, Accept, Authorization, X-Requested-With")
		c.Header("Access-Control-Max-Age", "86400")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}
