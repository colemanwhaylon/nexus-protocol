package config

import (
	"fmt"
	"strings"
	"time"

	"github.com/spf13/viper"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig
	Database DatabaseConfig
	Cache    CacheConfig
	RateLimit RateLimitConfig
	Logging  LoggingConfig
}

// ServerConfig holds server-related configuration
type ServerConfig struct {
	Port            int           `mapstructure:"port"`
	Host            string        `mapstructure:"host"`
	ReadTimeout     time.Duration `mapstructure:"read_timeout"`
	WriteTimeout    time.Duration `mapstructure:"write_timeout"`
	ShutdownTimeout time.Duration `mapstructure:"shutdown_timeout"`
	Mode            string        `mapstructure:"mode"` // debug, release, test
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Driver   string `mapstructure:"driver"` // sqlite, postgres
	Host     string `mapstructure:"host"`
	Port     int    `mapstructure:"port"`
	User     string `mapstructure:"user"`
	Password string `mapstructure:"password"`
	Name     string `mapstructure:"name"`
	SSLMode  string `mapstructure:"ssl_mode"`
}

// CacheConfig holds cache configuration
type CacheConfig struct {
	Type       string        `mapstructure:"type"` // memory, redis
	Host       string        `mapstructure:"host"`
	Port       int           `mapstructure:"port"`
	Password   string        `mapstructure:"password"`
	DB         int           `mapstructure:"db"`
	DefaultTTL time.Duration `mapstructure:"default_ttl"`
}

// RateLimitConfig holds rate limiting configuration
type RateLimitConfig struct {
	Enabled        bool          `mapstructure:"enabled"`
	RequestsPerMin int           `mapstructure:"requests_per_min"`
	BurstSize      int           `mapstructure:"burst_size"`
	CleanupInterval time.Duration `mapstructure:"cleanup_interval"`
}

// LoggingConfig holds logging configuration
type LoggingConfig struct {
	Level      string `mapstructure:"level"`  // debug, info, warn, error
	Format     string `mapstructure:"format"` // json, console
	OutputPath string `mapstructure:"output_path"`
}

// Load reads configuration from file and environment variables
func Load() (*Config, error) {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.AddConfigPath("./config")
	viper.AddConfigPath("/etc/nexus-protocol/")

	// Set defaults
	setDefaults()

	// Environment variable bindings
	viper.SetEnvPrefix("NEXUS")
	viper.SetEnvKeyReplacer(strings.NewReplacer(".", "_"))
	viper.AutomaticEnv()

	// Override with PORT env if set (common in containerized environments)
	if err := viper.BindEnv("server.port", "PORT"); err != nil {
		return nil, fmt.Errorf("failed to bind PORT env: %w", err)
	}

	// Try to read config file (optional)
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			return nil, fmt.Errorf("failed to read config file: %w", err)
		}
		// Config file not found is OK, we use defaults and env vars
	}

	var config Config
	if err := viper.Unmarshal(&config); err != nil {
		return nil, fmt.Errorf("failed to unmarshal config: %w", err)
	}

	return &config, nil
}

// setDefaults sets default configuration values
func setDefaults() {
	// Server defaults
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("server.host", "0.0.0.0")
	viper.SetDefault("server.read_timeout", 30*time.Second)
	viper.SetDefault("server.write_timeout", 30*time.Second)
	viper.SetDefault("server.shutdown_timeout", 15*time.Second)
	viper.SetDefault("server.mode", "release")

	// Database defaults (SQLite for dev)
	viper.SetDefault("database.driver", "sqlite")
	viper.SetDefault("database.host", "localhost")
	viper.SetDefault("database.port", 5432)
	viper.SetDefault("database.user", "nexus")
	viper.SetDefault("database.password", "")
	viper.SetDefault("database.name", "nexus.db")
	viper.SetDefault("database.ssl_mode", "disable")

	// Cache defaults (in-memory for dev)
	viper.SetDefault("cache.type", "memory")
	viper.SetDefault("cache.host", "localhost")
	viper.SetDefault("cache.port", 6379)
	viper.SetDefault("cache.password", "")
	viper.SetDefault("cache.db", 0)
	viper.SetDefault("cache.default_ttl", 5*time.Minute)

	// Rate limit defaults
	viper.SetDefault("ratelimit.enabled", true)
	viper.SetDefault("ratelimit.requests_per_min", 100)
	viper.SetDefault("ratelimit.burst_size", 10)
	viper.SetDefault("ratelimit.cleanup_interval", 1*time.Minute)

	// Logging defaults
	viper.SetDefault("logging.level", "info")
	viper.SetDefault("logging.format", "json")
	viper.SetDefault("logging.output_path", "stdout")
}

// GetDSN returns the database connection string
func (c *DatabaseConfig) GetDSN() string {
	switch c.Driver {
	case "sqlite":
		return c.Name
	case "postgres":
		return fmt.Sprintf(
			"host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
			c.Host, c.Port, c.User, c.Password, c.Name, c.SSLMode,
		)
	default:
		return c.Name
	}
}

// GetRedisAddr returns the Redis connection address
func (c *CacheConfig) GetRedisAddr() string {
	return fmt.Sprintf("%s:%d", c.Host, c.Port)
}
