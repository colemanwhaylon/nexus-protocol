// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"math/big"
	"time"
)

// GovernanceConfigRepository defines the contract for governance config data operations
type GovernanceConfigRepository interface {
	// Config CRUD
	GetConfig(ctx context.Context, configKey string, chainID int64) (*GovernanceConfig, error)
	ListConfigs(ctx context.Context, chainID int64, activeOnly bool) ([]*GovernanceConfig, error)
	UpdateConfig(ctx context.Context, configKey string, chainID int64, update *GovernanceConfigUpdate) error

	// Sync status
	MarkSynced(ctx context.Context, configKey string, chainID int64, txHash string) error

	// History (for audit)
	GetConfigHistory(ctx context.Context, configKey string, chainID int64, limit int) ([]*GovernanceConfigHistoryEntry, error)
}

// GovernanceConfig represents a governance configuration parameter
type GovernanceConfig struct {
	ID             string     `json:"id" db:"id"`
	ConfigKey      string     `json:"config_key" db:"config_key"`
	ConfigName     string     `json:"config_name" db:"config_name"`
	Description    string     `json:"description" db:"description"`
	ValueWei       *big.Int   `json:"value_wei" db:"value_wei"`           // Token amounts in wei
	ValueNumber    *int64     `json:"value_number" db:"value_number"`     // Numeric values (blocks, seconds)
	ValuePercent   *float64   `json:"value_percent" db:"value_percent"`   // Percentage values
	ValueString    *string    `json:"value_string" db:"value_string"`     // String values
	ValueType      string     `json:"value_type" db:"value_type"`         // 'wei', 'blocks', 'seconds', 'percent', 'string'
	UnitLabel      string     `json:"unit_label" db:"unit_label"`         // Display unit
	ChainID        int64      `json:"chain_id" db:"chain_id"`
	ContractSynced bool       `json:"contract_synced" db:"contract_synced"`
	LastSyncTx     *string    `json:"last_sync_tx" db:"last_sync_tx"`
	LastSyncAt     *time.Time `json:"last_sync_at" db:"last_sync_at"`
	IsActive       bool       `json:"is_active" db:"is_active"`
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
	UpdatedBy      *string    `json:"updated_by,omitempty" db:"updated_by"`
}

// GovernanceConfigUpdate represents fields that can be updated
type GovernanceConfigUpdate struct {
	ValueWei     *big.Int `json:"value_wei,omitempty"`
	ValueNumber  *int64   `json:"value_number,omitempty"`
	ValuePercent *float64 `json:"value_percent,omitempty"`
	ValueString  *string  `json:"value_string,omitempty"`
	IsActive     *bool    `json:"is_active,omitempty"`
	UpdatedBy    string   `json:"updated_by"`
}

// GovernanceConfigHistoryEntry represents a config change record
type GovernanceConfigHistoryEntry struct {
	ID                   string     `json:"id" db:"id"`
	GovernanceConfigID   string     `json:"governance_config_id" db:"governance_config_id"`
	OldValueWei          *big.Int   `json:"old_value_wei" db:"old_value_wei"`
	OldValueNumber       *int64     `json:"old_value_number" db:"old_value_number"`
	OldValuePercent      *float64   `json:"old_value_percent" db:"old_value_percent"`
	OldValueString       *string    `json:"old_value_string" db:"old_value_string"`
	NewValueWei          *big.Int   `json:"new_value_wei" db:"new_value_wei"`
	NewValueNumber       *int64     `json:"new_value_number" db:"new_value_number"`
	NewValuePercent      *float64   `json:"new_value_percent" db:"new_value_percent"`
	NewValueString       *string    `json:"new_value_string" db:"new_value_string"`
	WasSynced            *bool      `json:"was_synced" db:"was_synced"`
	SyncTx               *string    `json:"sync_tx" db:"sync_tx"`
	ChangedBy            string     `json:"changed_by" db:"changed_by"`
	ChangedAt            time.Time  `json:"changed_at" db:"changed_at"`
	ChangeReason         *string    `json:"change_reason" db:"change_reason"`
}

// Helper methods for GovernanceConfig

// GetDisplayValue returns the value formatted for display
func (c *GovernanceConfig) GetDisplayValue() string {
	switch c.ValueType {
	case "wei":
		if c.ValueWei != nil {
			// Convert wei to token units (divide by 10^18)
			tokenUnits := new(big.Float).Quo(
				new(big.Float).SetInt(c.ValueWei),
				new(big.Float).SetInt(big.NewInt(1e18)),
			)
			return tokenUnits.Text('f', 2) + " " + c.UnitLabel
		}
	case "blocks":
		if c.ValueNumber != nil {
			return formatInt64(*c.ValueNumber) + " " + c.UnitLabel
		}
	case "seconds":
		if c.ValueNumber != nil {
			return formatDuration(*c.ValueNumber)
		}
	case "percent":
		if c.ValuePercent != nil {
			return formatFloat64(*c.ValuePercent) + c.UnitLabel
		}
	case "string":
		if c.ValueString != nil {
			return *c.ValueString
		}
	}
	return "N/A"
}

// GetRawValue returns the raw numeric value for contract interaction
func (c *GovernanceConfig) GetRawValue() *big.Int {
	switch c.ValueType {
	case "wei":
		return c.ValueWei
	case "blocks", "seconds":
		if c.ValueNumber != nil {
			return big.NewInt(*c.ValueNumber)
		}
	case "percent":
		if c.ValuePercent != nil {
			// Convert percent to basis points (multiply by 100)
			// 4% = 400 basis points
			basisPoints := int64(*c.ValuePercent * 100)
			return big.NewInt(basisPoints)
		}
	}
	return nil
}

// Helper functions
func formatInt64(v int64) string {
	return big.NewInt(v).String()
}

func formatFloat64(v float64) string {
	return big.NewFloat(v).Text('f', 2)
}

func formatDuration(seconds int64) string {
	if seconds < 60 {
		return formatInt64(seconds) + " sec"
	}
	if seconds < 3600 {
		return formatInt64(seconds/60) + " min"
	}
	if seconds < 86400 {
		return formatInt64(seconds/3600) + " hr"
	}
	return formatInt64(seconds/86400) + " days"
}
