// Package repository defines the interfaces for data access
package repository

import (
	"context"
	"time"
)

// ContractRepository defines the contract for contract address data operations
type ContractRepository interface {
	// Network configuration
	GetNetworkByChainID(ctx context.Context, chainID int64) (*NetworkConfig, error)
	GetNetworkByName(ctx context.Context, name string) (*NetworkConfig, error)
	GetActiveNetworks(ctx context.Context) ([]*NetworkConfig, error)

	// Contract name mappings (read from DB, no hardcoded maps)
	GetAllMappings(ctx context.Context) ([]*ContractMapping, error)
	GetMappingBySolidityName(ctx context.Context, name string) (*ContractMapping, error)
	GetMappingByDBName(ctx context.Context, dbName string) (*ContractMapping, error)

	// Contract addresses
	GetByChainID(ctx context.Context, chainID int64) ([]*ContractAddress, error)
	GetByChainAndDBName(ctx context.Context, chainID int64, dbName string) (*ContractAddress, error)
	GetByID(ctx context.Context, id string) (*ContractAddress, error)
	Upsert(ctx context.Context, contract *ContractAddressUpsert) (*ContractAddress, error)

	// Deployment history (audit trail)
	GetHistory(ctx context.Context, contractID string, limit int) ([]*ContractAddressHistory, error)

	// Combined endpoint for deploy scripts - returns everything needed for deployment
	GetDeploymentConfig(ctx context.Context, chainID int64) (*DeploymentConfig, error)
}

// NetworkConfig represents per-network configuration from DB
type NetworkConfig struct {
	ID              string    `json:"id" db:"id"`
	ChainID         int64     `json:"chain_id" db:"chain_id"`
	NetworkName     string    `json:"network_name" db:"network_name"`
	DisplayName     string    `json:"display_name" db:"display_name"`
	RPCUrl          *string   `json:"rpc_url,omitempty" db:"rpc_url"`
	ExplorerUrl     *string   `json:"explorer_url,omitempty" db:"explorer_url"`
	DefaultDeployer *string   `json:"default_deployer,omitempty" db:"default_deployer"`
	IsTestnet       bool      `json:"is_testnet" db:"is_testnet"`
	IsActive        bool      `json:"is_active" db:"is_active"`
	CreatedAt       time.Time `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time `json:"updated_at" db:"updated_at"`
}

// ContractMapping represents Solidity→DB name mapping from DB
type ContractMapping struct {
	ID           string    `json:"id" db:"id"`
	SolidityName string    `json:"solidity_name" db:"solidity_name"`
	DBName       string    `json:"db_name" db:"db_name"`
	DisplayName  string    `json:"display_name" db:"display_name"`
	Category     string    `json:"category" db:"category"`
	Description  *string   `json:"description,omitempty" db:"description"`
	IsRequired   bool      `json:"is_required" db:"is_required"`
	SortOrder    int       `json:"sort_order" db:"sort_order"`
	CreatedAt    time.Time `json:"created_at" db:"created_at"`
}

// ContractAddress represents a deployed contract from DB
type ContractAddress struct {
	ID                string    `json:"id" db:"id"`
	ChainID           int64     `json:"chain_id" db:"chain_id"`
	ContractMappingID string    `json:"contract_mapping_id" db:"contract_mapping_id"`
	DBName            string    `json:"db_name" db:"db_name"`                   // Joined from contract_mappings
	SolidityName      string    `json:"solidity_name" db:"solidity_name"`       // Joined from contract_mappings
	Address           string    `json:"address" db:"address"`
	DeploymentTxHash  *string   `json:"deployment_tx_hash,omitempty" db:"deployment_tx_hash"`
	DeploymentBlock   *int64    `json:"deployment_block,omitempty" db:"deployment_block"`
	ABIVersion        string    `json:"abi_version" db:"abi_version"`
	Status            string    `json:"status" db:"status"`
	IsPrimary         bool      `json:"is_primary" db:"is_primary"`
	DeployedBy        *string   `json:"deployed_by,omitempty" db:"deployed_by"`
	Notes             *string   `json:"notes,omitempty" db:"notes"`
	CreatedAt         time.Time `json:"created_at" db:"created_at"`
	UpdatedAt         time.Time `json:"updated_at" db:"updated_at"`
}

// ContractAddressUpsert represents data for creating/updating a contract address
type ContractAddressUpsert struct {
	ChainID           int64   `json:"chain_id" binding:"required"`
	ContractMappingID string  `json:"contract_mapping_id" binding:"required"`
	Address           string  `json:"address" binding:"required"`
	DeploymentTxHash  *string `json:"deployment_tx_hash,omitempty"`
	DeploymentBlock   *int64  `json:"deployment_block,omitempty"`
	ABIVersion        *string `json:"abi_version,omitempty"`
	DeployedBy        *string `json:"deployed_by,omitempty"`
	Notes             *string `json:"notes,omitempty"`
}

// ContractAddressHistory represents an audit trail entry for address changes
type ContractAddressHistory struct {
	ID           string    `json:"id" db:"id"`
	ContractID   string    `json:"contract_id" db:"contract_id"`
	OldAddress   *string   `json:"old_address,omitempty" db:"old_address"`
	NewAddress   string    `json:"new_address" db:"new_address"`
	ChangeReason *string   `json:"change_reason,omitempty" db:"change_reason"`
	ChangedBy    string    `json:"changed_by" db:"changed_by"`
	ChangedAt    time.Time `json:"changed_at" db:"changed_at"`
}

// DeploymentConfig is the combined config returned to deploy scripts
type DeploymentConfig struct {
	Network   *NetworkConfig     `json:"network"`
	Mappings  []*ContractMapping `json:"mappings"`
	Contracts []*ContractAddress `json:"contracts"`
}
