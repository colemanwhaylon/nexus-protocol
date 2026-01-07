// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"encoding/json"
	"math/big"
	"time"
)

// AppConfigRepository defines the contract for app config data operations
type AppConfigRepository interface {
	// Get single config
	Get(ctx context.Context, namespace, key string, chainID int64) (*AppConfig, error)

	// Get with fallback (tries chain-specific first, then chain_id=0)
	GetWithFallback(ctx context.Context, namespace, key string, chainID int64) (*AppConfig, error)

	// List configs by namespace
	ListByNamespace(ctx context.Context, namespace string, chainID int64) ([]*AppConfig, error)

	// List all configs (for admin)
	ListAll(ctx context.Context) ([]*AppConfig, error)

	// Typed getters (with fallback)
	GetString(ctx context.Context, namespace, key string, chainID int64) (string, error)
	GetNumber(ctx context.Context, namespace, key string, chainID int64) (int64, error)
	GetWei(ctx context.Context, namespace, key string, chainID int64) (*big.Int, error)
	GetBool(ctx context.Context, namespace, key string, chainID int64) (bool, error)
	GetJSON(ctx context.Context, namespace, key string, chainID int64, dest interface{}) error

	// Update config
	Update(ctx context.Context, namespace, key string, chainID int64, update *AppConfigUpdate) error

	// Create config (for admin)
	Create(ctx context.Context, config *AppConfigCreate) error

	// Delete config (soft delete by setting is_active=false)
	Delete(ctx context.Context, namespace, key string, chainID int64, deletedBy string) error

	// History (for audit)
	GetHistory(ctx context.Context, namespace, key string, chainID int64, limit int) ([]*AppConfigHistoryEntry, error)
}

// AppConfig represents an application configuration value
type AppConfig struct {
	ID           string     `json:"id" db:"id"`
	Namespace    string     `json:"namespace" db:"namespace"`
	ConfigKey    string     `json:"config_key" db:"config_key"`
	ValueType    string     `json:"value_type" db:"value_type"` // 'string', 'number', 'wei', 'address', 'boolean', 'json'
	ValueString  *string    `json:"value_string,omitempty" db:"value_string"`
	ValueNumber  *int64     `json:"value_number,omitempty" db:"value_number"`
	ValueWei     *big.Int   `json:"value_wei,omitempty" db:"value_wei"`
	ValueBoolean *bool      `json:"value_boolean,omitempty" db:"value_boolean"`
	Description  string     `json:"description" db:"description"`
	IsSecret     bool       `json:"is_secret" db:"is_secret"`
	IsActive     bool       `json:"is_active" db:"is_active"`
	ChainID      int64      `json:"chain_id" db:"chain_id"`
	UpdatedBy    *string    `json:"updated_by,omitempty" db:"updated_by"`
	CreatedAt    time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt    time.Time  `json:"updated_at" db:"updated_at"`
}

// AppConfigUpdate represents fields that can be updated
type AppConfigUpdate struct {
	ValueString  *string `json:"value_string,omitempty"`
	ValueNumber  *int64  `json:"value_number,omitempty"`
	ValueWei     *big.Int `json:"value_wei,omitempty"`
	ValueBoolean *bool   `json:"value_boolean,omitempty"`
	Description  *string `json:"description,omitempty"`
	IsActive     *bool   `json:"is_active,omitempty"`
	UpdatedBy    string  `json:"updated_by"`
}

// AppConfigCreate represents fields for creating a new config
type AppConfigCreate struct {
	Namespace    string   `json:"namespace"`
	ConfigKey    string   `json:"config_key"`
	ValueType    string   `json:"value_type"`
	ValueString  *string  `json:"value_string,omitempty"`
	ValueNumber  *int64   `json:"value_number,omitempty"`
	ValueWei     *big.Int `json:"value_wei,omitempty"`
	ValueBoolean *bool    `json:"value_boolean,omitempty"`
	Description  string   `json:"description"`
	IsSecret     bool     `json:"is_secret"`
	ChainID      int64    `json:"chain_id"`
	UpdatedBy    string   `json:"updated_by"`
}

// AppConfigHistoryEntry represents a config change record
type AppConfigHistoryEntry struct {
	ID              string    `json:"id" db:"id"`
	AppConfigID     string    `json:"app_config_id" db:"app_config_id"`
	OldValueString  *string   `json:"old_value_string,omitempty" db:"old_value_string"`
	OldValueNumber  *int64    `json:"old_value_number,omitempty" db:"old_value_number"`
	OldValueWei     *big.Int  `json:"old_value_wei,omitempty" db:"old_value_wei"`
	OldValueBoolean *bool     `json:"old_value_boolean,omitempty" db:"old_value_boolean"`
	NewValueString  *string   `json:"new_value_string,omitempty" db:"new_value_string"`
	NewValueNumber  *int64    `json:"new_value_number,omitempty" db:"new_value_number"`
	NewValueWei     *big.Int  `json:"new_value_wei,omitempty" db:"new_value_wei"`
	NewValueBoolean *bool     `json:"new_value_boolean,omitempty" db:"new_value_boolean"`
	ChangedBy       string    `json:"changed_by" db:"changed_by"`
	ChangedAt       time.Time `json:"changed_at" db:"changed_at"`
	ChangeReason    *string   `json:"change_reason,omitempty" db:"change_reason"`
}

// Helper methods for AppConfig

// GetValue returns the appropriate value based on value_type
func (c *AppConfig) GetValue() interface{} {
	switch c.ValueType {
	case "string", "address", "json":
		if c.ValueString != nil {
			return *c.ValueString
		}
	case "number":
		if c.ValueNumber != nil {
			return *c.ValueNumber
		}
	case "wei":
		if c.ValueWei != nil {
			return c.ValueWei
		}
	case "boolean":
		if c.ValueBoolean != nil {
			return *c.ValueBoolean
		}
	}
	return nil
}

// GetStringValue returns the string value or empty string
func (c *AppConfig) GetStringValue() string {
	if c.ValueString != nil {
		return *c.ValueString
	}
	return ""
}

// GetNumberValue returns the number value or 0
func (c *AppConfig) GetNumberValue() int64 {
	if c.ValueNumber != nil {
		return *c.ValueNumber
	}
	return 0
}

// GetWeiValue returns the wei value or nil
func (c *AppConfig) GetWeiValue() *big.Int {
	return c.ValueWei
}

// GetBoolValue returns the boolean value or false
func (c *AppConfig) GetBoolValue() bool {
	if c.ValueBoolean != nil {
		return *c.ValueBoolean
	}
	return false
}

// ParseJSON parses the string value as JSON into dest
func (c *AppConfig) ParseJSON(dest interface{}) error {
	if c.ValueString == nil {
		return nil
	}
	return json.Unmarshal([]byte(*c.ValueString), dest)
}

// MaskedValue returns the value with sensitive data masked
func (c *AppConfig) MaskedValue() interface{} {
	if c.IsSecret {
		return "********"
	}
	return c.GetValue()
}
