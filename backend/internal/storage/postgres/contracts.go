// Package postgres implements repository interfaces using PostgreSQL
package postgres

import (
	"context"
	"database/sql"
	"errors"
	"fmt"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// Ensure PostgresContractRepo implements ContractRepository
var _ repository.ContractRepository = (*PostgresContractRepo)(nil)

// PostgresContractRepo implements ContractRepository using PostgreSQL
type PostgresContractRepo struct {
	db *sql.DB
}

// NewPostgresContractRepo creates a new PostgreSQL contract repository
func NewPostgresContractRepo(db *sql.DB) *PostgresContractRepo {
	return &PostgresContractRepo{db: db}
}

// ============================================================================
// Network Configuration Methods
// ============================================================================

// GetNetworkByChainID retrieves network configuration by chain ID
func (r *PostgresContractRepo) GetNetworkByChainID(ctx context.Context, chainID int64) (*repository.NetworkConfig, error) {
	query := `
		SELECT id, chain_id, network_name, display_name, rpc_url, explorer_url,
		       default_deployer, is_testnet, is_active, created_at, updated_at
		FROM network_config
		WHERE chain_id = $1
	`

	nc := &repository.NetworkConfig{}
	err := r.db.QueryRowContext(ctx, query, chainID).Scan(
		&nc.ID,
		&nc.ChainID,
		&nc.NetworkName,
		&nc.DisplayName,
		&nc.RPCUrl,
		&nc.ExplorerUrl,
		&nc.DefaultDeployer,
		&nc.IsTestnet,
		&nc.IsActive,
		&nc.CreatedAt,
		&nc.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrNetworkNotFound
		}
		return nil, fmt.Errorf("getting network config for chain %d: %w", chainID, err)
	}

	return nc, nil
}

// GetNetworkByName retrieves network configuration by network name
func (r *PostgresContractRepo) GetNetworkByName(ctx context.Context, name string) (*repository.NetworkConfig, error) {
	query := `
		SELECT id, chain_id, network_name, display_name, rpc_url, explorer_url,
		       default_deployer, is_testnet, is_active, created_at, updated_at
		FROM network_config
		WHERE network_name = $1
	`

	nc := &repository.NetworkConfig{}
	err := r.db.QueryRowContext(ctx, query, name).Scan(
		&nc.ID,
		&nc.ChainID,
		&nc.NetworkName,
		&nc.DisplayName,
		&nc.RPCUrl,
		&nc.ExplorerUrl,
		&nc.DefaultDeployer,
		&nc.IsTestnet,
		&nc.IsActive,
		&nc.CreatedAt,
		&nc.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrNetworkNotFound
		}
		return nil, fmt.Errorf("getting network config for %s: %w", name, err)
	}

	return nc, nil
}

// GetActiveNetworks retrieves all active network configurations
func (r *PostgresContractRepo) GetActiveNetworks(ctx context.Context) ([]*repository.NetworkConfig, error) {
	query := `
		SELECT id, chain_id, network_name, display_name, rpc_url, explorer_url,
		       default_deployer, is_testnet, is_active, created_at, updated_at
		FROM network_config
		WHERE is_active = true
		ORDER BY chain_id
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("listing active networks: %w", err)
	}
	defer rows.Close()

	var result []*repository.NetworkConfig
	for rows.Next() {
		nc := &repository.NetworkConfig{}
		err := rows.Scan(
			&nc.ID,
			&nc.ChainID,
			&nc.NetworkName,
			&nc.DisplayName,
			&nc.RPCUrl,
			&nc.ExplorerUrl,
			&nc.DefaultDeployer,
			&nc.IsTestnet,
			&nc.IsActive,
			&nc.CreatedAt,
			&nc.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning network config row: %w", err)
		}
		result = append(result, nc)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating network config rows: %w", err)
	}

	return result, nil
}

// ============================================================================
// Contract Mapping Methods
// ============================================================================

// GetAllMappings retrieves all contract name mappings from DB
func (r *PostgresContractRepo) GetAllMappings(ctx context.Context) ([]*repository.ContractMapping, error) {
	query := `
		SELECT id, solidity_name, db_name, display_name, category, description,
		       is_required, sort_order, created_at
		FROM contract_mappings
		ORDER BY sort_order, solidity_name
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("listing contract mappings: %w", err)
	}
	defer rows.Close()

	var result []*repository.ContractMapping
	for rows.Next() {
		cm := &repository.ContractMapping{}
		err := rows.Scan(
			&cm.ID,
			&cm.SolidityName,
			&cm.DBName,
			&cm.DisplayName,
			&cm.Category,
			&cm.Description,
			&cm.IsRequired,
			&cm.SortOrder,
			&cm.CreatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning contract mapping row: %w", err)
		}
		result = append(result, cm)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating contract mapping rows: %w", err)
	}

	return result, nil
}

// GetMappingBySolidityName retrieves a contract mapping by Solidity contract name
func (r *PostgresContractRepo) GetMappingBySolidityName(ctx context.Context, name string) (*repository.ContractMapping, error) {
	query := `
		SELECT id, solidity_name, db_name, display_name, category, description,
		       is_required, sort_order, created_at
		FROM contract_mappings
		WHERE solidity_name = $1
	`

	cm := &repository.ContractMapping{}
	err := r.db.QueryRowContext(ctx, query, name).Scan(
		&cm.ID,
		&cm.SolidityName,
		&cm.DBName,
		&cm.DisplayName,
		&cm.Category,
		&cm.Description,
		&cm.IsRequired,
		&cm.SortOrder,
		&cm.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrContractMappingNotFound
		}
		return nil, fmt.Errorf("getting contract mapping for %s: %w", name, err)
	}

	return cm, nil
}

// GetMappingByDBName retrieves a contract mapping by database name
func (r *PostgresContractRepo) GetMappingByDBName(ctx context.Context, dbName string) (*repository.ContractMapping, error) {
	query := `
		SELECT id, solidity_name, db_name, display_name, category, description,
		       is_required, sort_order, created_at
		FROM contract_mappings
		WHERE db_name = $1
	`

	cm := &repository.ContractMapping{}
	err := r.db.QueryRowContext(ctx, query, dbName).Scan(
		&cm.ID,
		&cm.SolidityName,
		&cm.DBName,
		&cm.DisplayName,
		&cm.Category,
		&cm.Description,
		&cm.IsRequired,
		&cm.SortOrder,
		&cm.CreatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrContractMappingNotFound
		}
		return nil, fmt.Errorf("getting contract mapping for db_name %s: %w", dbName, err)
	}

	return cm, nil
}

// ============================================================================
// Contract Address Methods
// ============================================================================

// GetByChainID retrieves all contract addresses for a specific chain
func (r *PostgresContractRepo) GetByChainID(ctx context.Context, chainID int64) ([]*repository.ContractAddress, error) {
	query := `
		SELECT ca.id, ca.chain_id, ca.contract_mapping_id, cm.db_name, cm.solidity_name,
		       ca.address, ca.deployment_tx_hash, ca.deployment_block, ca.abi_version,
		       ca.status, ca.is_primary, ca.deployed_by, ca.notes, ca.created_at, ca.updated_at
		FROM contract_addresses ca
		JOIN contract_mappings cm ON ca.contract_mapping_id = cm.id
		WHERE ca.chain_id = $1 AND ca.status = 'active' AND ca.is_primary = true
		ORDER BY cm.sort_order, cm.solidity_name
	`

	rows, err := r.db.QueryContext(ctx, query, chainID)
	if err != nil {
		return nil, fmt.Errorf("listing contracts for chain %d: %w", chainID, err)
	}
	defer rows.Close()

	var result []*repository.ContractAddress
	for rows.Next() {
		ca := &repository.ContractAddress{}
		err := rows.Scan(
			&ca.ID,
			&ca.ChainID,
			&ca.ContractMappingID,
			&ca.DBName,
			&ca.SolidityName,
			&ca.Address,
			&ca.DeploymentTxHash,
			&ca.DeploymentBlock,
			&ca.ABIVersion,
			&ca.Status,
			&ca.IsPrimary,
			&ca.DeployedBy,
			&ca.Notes,
			&ca.CreatedAt,
			&ca.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning contract address row: %w", err)
		}
		result = append(result, ca)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating contract address rows: %w", err)
	}

	return result, nil
}

// GetByChainAndDBName retrieves a specific contract address by chain ID and db_name
func (r *PostgresContractRepo) GetByChainAndDBName(ctx context.Context, chainID int64, dbName string) (*repository.ContractAddress, error) {
	query := `
		SELECT ca.id, ca.chain_id, ca.contract_mapping_id, cm.db_name, cm.solidity_name,
		       ca.address, ca.deployment_tx_hash, ca.deployment_block, ca.abi_version,
		       ca.status, ca.is_primary, ca.deployed_by, ca.notes, ca.created_at, ca.updated_at
		FROM contract_addresses ca
		JOIN contract_mappings cm ON ca.contract_mapping_id = cm.id
		WHERE ca.chain_id = $1 AND cm.db_name = $2 AND ca.status = 'active' AND ca.is_primary = true
	`

	ca := &repository.ContractAddress{}
	err := r.db.QueryRowContext(ctx, query, chainID, dbName).Scan(
		&ca.ID,
		&ca.ChainID,
		&ca.ContractMappingID,
		&ca.DBName,
		&ca.SolidityName,
		&ca.Address,
		&ca.DeploymentTxHash,
		&ca.DeploymentBlock,
		&ca.ABIVersion,
		&ca.Status,
		&ca.IsPrimary,
		&ca.DeployedBy,
		&ca.Notes,
		&ca.CreatedAt,
		&ca.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrContractAddressNotFound
		}
		return nil, fmt.Errorf("getting contract %s on chain %d: %w", dbName, chainID, err)
	}

	return ca, nil
}

// GetByID retrieves a contract address by its ID
func (r *PostgresContractRepo) GetByID(ctx context.Context, id string) (*repository.ContractAddress, error) {
	query := `
		SELECT ca.id, ca.chain_id, ca.contract_mapping_id, cm.db_name, cm.solidity_name,
		       ca.address, ca.deployment_tx_hash, ca.deployment_block, ca.abi_version,
		       ca.status, ca.is_primary, ca.deployed_by, ca.notes, ca.created_at, ca.updated_at
		FROM contract_addresses ca
		JOIN contract_mappings cm ON ca.contract_mapping_id = cm.id
		WHERE ca.id = $1
	`

	ca := &repository.ContractAddress{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&ca.ID,
		&ca.ChainID,
		&ca.ContractMappingID,
		&ca.DBName,
		&ca.SolidityName,
		&ca.Address,
		&ca.DeploymentTxHash,
		&ca.DeploymentBlock,
		&ca.ABIVersion,
		&ca.Status,
		&ca.IsPrimary,
		&ca.DeployedBy,
		&ca.Notes,
		&ca.CreatedAt,
		&ca.UpdatedAt,
	)

	if err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, repository.ErrContractAddressNotFound
		}
		return nil, fmt.Errorf("getting contract by id %s: %w", id, err)
	}

	return ca, nil
}

// Upsert creates or updates a contract address
// If a contract with the same chain_id + contract_mapping_id + is_primary=true exists,
// it updates the address and logs history. Otherwise, it creates a new record.
func (r *PostgresContractRepo) Upsert(ctx context.Context, contract *repository.ContractAddressUpsert) (*repository.ContractAddress, error) {
	// Start transaction
	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return nil, fmt.Errorf("starting transaction: %w", err)
	}
	defer tx.Rollback()

	// Validate chain exists
	var chainExists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM network_config WHERE chain_id = $1)", contract.ChainID).Scan(&chainExists)
	if err != nil {
		return nil, fmt.Errorf("checking chain existence: %w", err)
	}
	if !chainExists {
		return nil, repository.ErrNetworkNotFound
	}

	// Validate mapping exists
	var mappingExists bool
	err = tx.QueryRowContext(ctx, "SELECT EXISTS(SELECT 1 FROM contract_mappings WHERE id = $1)", contract.ContractMappingID).Scan(&mappingExists)
	if err != nil {
		return nil, fmt.Errorf("checking mapping existence: %w", err)
	}
	if !mappingExists {
		return nil, repository.ErrContractMappingNotFound
	}

	// Get default deployer from network if not provided
	deployedBy := contract.DeployedBy
	if deployedBy == nil || *deployedBy == "" {
		var defaultDeployer sql.NullString
		err = tx.QueryRowContext(ctx, "SELECT default_deployer FROM network_config WHERE chain_id = $1", contract.ChainID).Scan(&defaultDeployer)
		if err != nil && !errors.Is(err, sql.ErrNoRows) {
			return nil, fmt.Errorf("getting default deployer: %w", err)
		}
		if defaultDeployer.Valid {
			deployedBy = &defaultDeployer.String
		}
	}

	// Check if primary contract already exists for this chain+mapping
	var existingID sql.NullString
	var existingAddress sql.NullString
	err = tx.QueryRowContext(ctx, `
		SELECT id, address FROM contract_addresses
		WHERE chain_id = $1 AND contract_mapping_id = $2 AND is_primary = true
	`, contract.ChainID, contract.ContractMappingID).Scan(&existingID, &existingAddress)

	abiVersion := "1.0.0"
	if contract.ABIVersion != nil {
		abiVersion = *contract.ABIVersion
	}

	var contractID string
	if errors.Is(err, sql.ErrNoRows) {
		// INSERT new contract
		insertQuery := `
			INSERT INTO contract_addresses (
				chain_id, contract_mapping_id, address, deployment_tx_hash,
				deployment_block, abi_version, deployed_by, notes, status, is_primary
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, 'active', true)
			RETURNING id
		`
		err = tx.QueryRowContext(ctx, insertQuery,
			contract.ChainID,
			contract.ContractMappingID,
			contract.Address,
			contract.DeploymentTxHash,
			contract.DeploymentBlock,
			abiVersion,
			deployedBy,
			contract.Notes,
		).Scan(&contractID)
		if err != nil {
			return nil, fmt.Errorf("inserting contract address: %w", err)
		}

		// Log initial deployment in history
		historyQuery := `
			INSERT INTO contract_addresses_history (contract_id, old_address, new_address, change_reason, changed_by)
			VALUES ($1, NULL, $2, 'Initial deployment', $3)
		`
		changedBy := "unknown"
		if deployedBy != nil {
			changedBy = *deployedBy
		}
		_, err = tx.ExecContext(ctx, historyQuery, contractID, contract.Address, changedBy)
		if err != nil {
			return nil, fmt.Errorf("logging deployment history: %w", err)
		}
	} else if err != nil {
		return nil, fmt.Errorf("checking existing contract: %w", err)
	} else {
		// UPDATE existing contract
		contractID = existingID.String
		oldAddress := existingAddress.String

		updateQuery := `
			UPDATE contract_addresses
			SET address = $1, deployment_tx_hash = $2, deployment_block = $3,
			    abi_version = $4, deployed_by = $5, notes = $6, updated_at = NOW()
			WHERE id = $7
		`
		_, err = tx.ExecContext(ctx, updateQuery,
			contract.Address,
			contract.DeploymentTxHash,
			contract.DeploymentBlock,
			abiVersion,
			deployedBy,
			contract.Notes,
			contractID,
		)
		if err != nil {
			return nil, fmt.Errorf("updating contract address: %w", err)
		}

		// Log update in history (if address changed)
		if oldAddress != contract.Address {
			historyQuery := `
				INSERT INTO contract_addresses_history (contract_id, old_address, new_address, change_reason, changed_by)
				VALUES ($1, $2, $3, 'Contract redeployed', $4)
			`
			changedBy := "unknown"
			if deployedBy != nil {
				changedBy = *deployedBy
			}
			_, err = tx.ExecContext(ctx, historyQuery, contractID, oldAddress, contract.Address, changedBy)
			if err != nil {
				return nil, fmt.Errorf("logging address change history: %w", err)
			}
		}
	}

	// Commit transaction
	if err := tx.Commit(); err != nil {
		return nil, fmt.Errorf("committing transaction: %w", err)
	}

	// Fetch and return the complete contract record
	return r.GetByID(ctx, contractID)
}

// ============================================================================
// History Methods
// ============================================================================

// GetHistory retrieves deployment history for a contract
func (r *PostgresContractRepo) GetHistory(ctx context.Context, contractID string, limit int) ([]*repository.ContractAddressHistory, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	query := `
		SELECT id, contract_id, old_address, new_address, change_reason, changed_by, changed_at
		FROM contract_addresses_history
		WHERE contract_id = $1
		ORDER BY changed_at DESC
		LIMIT $2
	`

	rows, err := r.db.QueryContext(ctx, query, contractID, limit)
	if err != nil {
		return nil, fmt.Errorf("getting contract history: %w", err)
	}
	defer rows.Close()

	var result []*repository.ContractAddressHistory
	for rows.Next() {
		h := &repository.ContractAddressHistory{}
		err := rows.Scan(
			&h.ID,
			&h.ContractID,
			&h.OldAddress,
			&h.NewAddress,
			&h.ChangeReason,
			&h.ChangedBy,
			&h.ChangedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("scanning history row: %w", err)
		}
		result = append(result, h)
	}

	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterating history rows: %w", err)
	}

	return result, nil
}

// ============================================================================
// Deployment Config Method
// ============================================================================

// GetDeploymentConfig returns all config needed for deployment scripts
func (r *PostgresContractRepo) GetDeploymentConfig(ctx context.Context, chainID int64) (*repository.DeploymentConfig, error) {
	// 1. Get network config (includes default_deployer)
	network, err := r.GetNetworkByChainID(ctx, chainID)
	if err != nil {
		return nil, err
	}

	// 2. Get all contract mappings (Solidity→DB name)
	mappings, err := r.GetAllMappings(ctx)
	if err != nil {
		return nil, err
	}

	// 3. Get existing contracts for this chain
	contracts, err := r.GetByChainID(ctx, chainID)
	if err != nil {
		return nil, err
	}

	return &repository.DeploymentConfig{
		Network:   network,
		Mappings:  mappings,
		Contracts: contracts,
	}, nil
}
