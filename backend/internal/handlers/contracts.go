package handlers

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// ContractHandler handles contract address related API endpoints
type ContractHandler struct {
	repo   repository.ContractRepository
	logger *zap.Logger
}

// NewContractHandler creates a new contract handler with injected dependencies
func NewContractHandler(repo repository.ContractRepository, logger *zap.Logger) *ContractHandler {
	return &ContractHandler{
		repo:   repo,
		logger: logger,
	}
}

// ContractResponse wraps contract API responses
type ContractResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// UpsertContractRequest represents a request to register/update a contract
type UpsertContractRequest struct {
	ChainID           int64   `json:"chain_id" binding:"required"`
	ContractMappingID string  `json:"contract_mapping_id" binding:"required"`
	Address           string  `json:"address" binding:"required"`
	DeploymentTxHash  *string `json:"deployment_tx_hash,omitempty"`
	DeploymentBlock   *int64  `json:"deployment_block,omitempty"`
	ABIVersion        *string `json:"abi_version,omitempty"`
	DeployedBy        *string `json:"deployed_by,omitempty"`
	Notes             *string `json:"notes,omitempty"`
}

// ============================================================================
// Network Endpoints
// ============================================================================

// ListNetworks handles GET /api/v1/networks
// @Summary List all active networks
// @Description Returns all active network configurations
// @Tags networks
// @Produce json
// @Success 200 {object} ContractResponse
// @Router /api/v1/networks [get]
func (h *ContractHandler) ListNetworks(c *gin.Context) {
	networks, err := h.repo.GetActiveNetworks(c.Request.Context())
	if err != nil {
		h.logger.Error("failed to list networks", zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data: gin.H{
			"networks": networks,
			"total":    len(networks),
		},
	})
}

// GetNetwork handles GET /api/v1/networks/:chainId
// @Summary Get network configuration by chain ID
// @Description Returns network configuration for a specific chain ID
// @Tags networks
// @Produce json
// @Param chainId path int true "Chain ID"
// @Success 200 {object} ContractResponse
// @Failure 404 {object} ContractResponse
// @Router /api/v1/networks/{chainId} [get]
func (h *ContractHandler) GetNetwork(c *gin.Context) {
	chainIDStr := c.Param("chainId")
	chainID, err := strconv.ParseInt(chainIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid chain ID format",
		})
		return
	}

	network, err := h.repo.GetNetworkByChainID(c.Request.Context(), chainID)
	if err != nil {
		if errors.Is(err, repository.ErrNetworkNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Network not found for chain ID: " + chainIDStr,
			})
			return
		}
		h.logger.Error("failed to get network", zap.Int64("chainId", chainID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data:    network,
	})
}

// ============================================================================
// Contract Mapping Endpoints
// ============================================================================

// ListMappings handles GET /api/v1/contracts/mappings
// @Summary List all contract name mappings
// @Description Returns all contract Solidity→DB name mappings from database
// @Tags contracts
// @Produce json
// @Success 200 {object} ContractResponse
// @Router /api/v1/contracts/mappings [get]
func (h *ContractHandler) ListMappings(c *gin.Context) {
	mappings, err := h.repo.GetAllMappings(c.Request.Context())
	if err != nil {
		h.logger.Error("failed to list mappings", zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data: gin.H{
			"mappings": mappings,
			"total":    len(mappings),
		},
	})
}

// ============================================================================
// Deployment Config Endpoint (for deploy scripts)
// ============================================================================

// GetDeploymentConfig handles GET /api/v1/contracts/config/:chainId
// @Summary Get full deployment configuration
// @Description Returns network config, contract mappings, and existing contracts for deploy scripts
// @Tags contracts
// @Produce json
// @Param chainId path int true "Chain ID"
// @Success 200 {object} ContractResponse
// @Failure 404 {object} ContractResponse
// @Router /api/v1/contracts/config/{chainId} [get]
func (h *ContractHandler) GetDeploymentConfig(c *gin.Context) {
	chainIDStr := c.Param("chainId")
	chainID, err := strconv.ParseInt(chainIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid chain ID format",
		})
		return
	}

	config, err := h.repo.GetDeploymentConfig(c.Request.Context(), chainID)
	if err != nil {
		if errors.Is(err, repository.ErrNetworkNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Network not found for chain ID: " + chainIDStr,
			})
			return
		}
		h.logger.Error("failed to get deployment config", zap.Int64("chainId", chainID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data:    config,
	})
}

// ============================================================================
// Contract Address Endpoints
// ============================================================================

// ListContracts handles GET /api/v1/contracts/:chainId
// @Summary List all contracts for a chain
// @Description Returns all deployed contract addresses for a specific chain
// @Tags contracts
// @Produce json
// @Param chainId path int true "Chain ID"
// @Success 200 {object} ContractResponse
// @Router /api/v1/contracts/{chainId} [get]
func (h *ContractHandler) ListContracts(c *gin.Context) {
	chainIDStr := c.Param("chainId")
	chainID, err := strconv.ParseInt(chainIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid chain ID format",
		})
		return
	}

	contracts, err := h.repo.GetByChainID(c.Request.Context(), chainID)
	if err != nil {
		h.logger.Error("failed to list contracts", zap.Int64("chainId", chainID), zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data: gin.H{
			"contracts": contracts,
			"total":     len(contracts),
		},
	})
}

// GetContract handles GET /api/v1/contracts/:chainId/:name
// @Summary Get a specific contract by chain ID and db_name
// @Description Returns a contract address by chain ID and database name (e.g., nexusToken)
// @Tags contracts
// @Produce json
// @Param chainId path int true "Chain ID"
// @Param name path string true "Contract DB name (e.g., nexusToken)"
// @Success 200 {object} ContractResponse
// @Failure 404 {object} ContractResponse
// @Router /api/v1/contracts/{chainId}/{name} [get]
func (h *ContractHandler) GetContract(c *gin.Context) {
	chainIDStr := c.Param("chainId")
	chainID, err := strconv.ParseInt(chainIDStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid chain ID format",
		})
		return
	}

	name := c.Param("name")
	if name == "" {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Contract name is required",
		})
		return
	}

	contract, err := h.repo.GetByChainAndDBName(c.Request.Context(), chainID, name)
	if err != nil {
		if errors.Is(err, repository.ErrContractAddressNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Contract not found: " + name + " on chain " + chainIDStr,
			})
			return
		}
		h.logger.Error("failed to get contract",
			zap.Int64("chainId", chainID),
			zap.String("name", name),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data:    contract,
	})
}

// UpsertContract handles POST /api/v1/contracts
// @Summary Register or update a contract address
// @Description Upserts a contract address. Uses DB config for deployer if not provided.
// @Tags contracts
// @Accept json
// @Produce json
// @Param request body UpsertContractRequest true "Contract registration request"
// @Success 200 {object} ContractResponse
// @Failure 400 {object} ContractResponse
// @Failure 404 {object} ContractResponse
// @Router /api/v1/contracts [post]
func (h *ContractHandler) UpsertContract(c *gin.Context) {
	var req UpsertContractRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate address format (basic check)
	if !isValidAddress(req.Address) {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid contract address format",
		})
		return
	}

	// Validate deployer address if provided
	if req.DeployedBy != nil && *req.DeployedBy != "" && !isValidAddress(*req.DeployedBy) {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Invalid deployer address format",
		})
		return
	}

	upsert := &repository.ContractAddressUpsert{
		ChainID:           req.ChainID,
		ContractMappingID: req.ContractMappingID,
		Address:           req.Address,
		DeploymentTxHash:  req.DeploymentTxHash,
		DeploymentBlock:   req.DeploymentBlock,
		ABIVersion:        req.ABIVersion,
		DeployedBy:        req.DeployedBy,
		Notes:             req.Notes,
	}

	contract, err := h.repo.Upsert(c.Request.Context(), upsert)
	if err != nil {
		if errors.Is(err, repository.ErrNetworkNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Network not found for chain ID",
			})
			return
		}
		if errors.Is(err, repository.ErrContractMappingNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Contract mapping not found",
			})
			return
		}
		h.logger.Error("failed to upsert contract",
			zap.Int64("chainId", req.ChainID),
			zap.String("mappingId", req.ContractMappingID),
			zap.String("address", req.Address),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Failed to register contract",
		})
		return
	}

	h.logger.Info("contract registered",
		zap.Int64("chainId", contract.ChainID),
		zap.String("name", contract.DBName),
		zap.String("address", contract.Address),
	)

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data: gin.H{
			"contract": contract,
		},
		Message: "Contract registered successfully",
	})
}

// ============================================================================
// History Endpoint
// ============================================================================

// GetContractHistory handles GET /api/v1/contracts/history/:id
// @Summary Get contract deployment history
// @Description Returns the deployment history for a specific contract
// @Tags contracts
// @Produce json
// @Param id path string true "Contract ID (UUID)"
// @Param limit query int false "Number of entries (default: 20, max: 100)"
// @Success 200 {object} ContractResponse
// @Failure 404 {object} ContractResponse
// @Router /api/v1/contracts/history/{id} [get]
func (h *ContractHandler) GetContractHistory(c *gin.Context) {
	id := c.Param("id")
	if id == "" {
		c.JSON(http.StatusBadRequest, ContractResponse{
			Success: false,
			Error:   "Contract ID is required",
		})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	if limit < 1 || limit > 100 {
		limit = 20
	}

	// Verify contract exists
	contract, err := h.repo.GetByID(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrContractAddressNotFound) {
			c.JSON(http.StatusNotFound, ContractResponse{
				Success: false,
				Error:   "Contract not found",
			})
			return
		}
		h.logger.Error("failed to get contract", zap.String("id", id), zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	history, err := h.repo.GetHistory(c.Request.Context(), id, limit)
	if err != nil {
		h.logger.Error("failed to get contract history", zap.String("id", id), zap.Error(err))
		c.JSON(http.StatusInternalServerError, ContractResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, ContractResponse{
		Success: true,
		Data: gin.H{
			"contract_id":   id,
			"contract_name": contract.DBName,
			"chain_id":      contract.ChainID,
			"history":       history,
			"total":         len(history),
		},
	})
}
