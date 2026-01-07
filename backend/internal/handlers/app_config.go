// Package handlers implements HTTP handlers for the API
package handlers

import (
	"math/big"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// AppConfigHandler handles app configuration API endpoints
type AppConfigHandler struct {
	repo   repository.AppConfigRepository
	logger *zap.Logger
}

// NewAppConfigHandler creates a new app config handler
func NewAppConfigHandler(repo repository.AppConfigRepository, logger *zap.Logger) *AppConfigHandler {
	return &AppConfigHandler{
		repo:   repo,
		logger: logger,
	}
}

// AppConfigResponse wraps a single config response
type AppConfigResponse struct {
	Success bool                  `json:"success"`
	Config  *AppConfigDTO         `json:"config,omitempty"`
	Message string                `json:"message,omitempty"`
}

// AppConfigListResponse wraps a list of configs response
type AppConfigListResponse struct {
	Success bool            `json:"success"`
	Configs []*AppConfigDTO `json:"configs"`
	Total   int             `json:"total"`
	Message string          `json:"message,omitempty"`
}

// AppConfigDTO is the API representation of an app config
type AppConfigDTO struct {
	ID           string      `json:"id"`
	Namespace    string      `json:"namespace"`
	ConfigKey    string      `json:"config_key"`
	ValueType    string      `json:"value_type"`
	Value        interface{} `json:"value"`
	Description  string      `json:"description"`
	IsSecret     bool        `json:"is_secret"`
	IsActive     bool        `json:"is_active"`
	ChainID      int64       `json:"chain_id"`
	UpdatedBy    *string     `json:"updated_by,omitempty"`
	CreatedAt    string      `json:"created_at"`
	UpdatedAt    string      `json:"updated_at"`
}

// AppConfigUpdateRequest represents an update request
type AppConfigUpdateRequest struct {
	Value       interface{} `json:"value"`
	Description *string     `json:"description,omitempty"`
	UpdatedBy   string      `json:"updated_by" binding:"required"`
}

// AppConfigCreateRequest represents a create request
type AppConfigCreateRequest struct {
	Namespace   string      `json:"namespace" binding:"required"`
	ConfigKey   string      `json:"config_key" binding:"required"`
	ValueType   string      `json:"value_type" binding:"required"`
	Value       interface{} `json:"value" binding:"required"`
	Description string      `json:"description"`
	IsSecret    bool        `json:"is_secret"`
	ChainID     int64       `json:"chain_id"`
	UpdatedBy   string      `json:"updated_by" binding:"required"`
}

// toDTO converts a repository AppConfig to an API DTO
func (h *AppConfigHandler) toDTO(c *repository.AppConfig) *AppConfigDTO {
	dto := &AppConfigDTO{
		ID:          c.ID,
		Namespace:   c.Namespace,
		ConfigKey:   c.ConfigKey,
		ValueType:   c.ValueType,
		Description: c.Description,
		IsSecret:    c.IsSecret,
		IsActive:    c.IsActive,
		ChainID:     c.ChainID,
		UpdatedBy:   c.UpdatedBy,
		CreatedAt:   c.CreatedAt.Format("2006-01-02T15:04:05Z07:00"),
		UpdatedAt:   c.UpdatedAt.Format("2006-01-02T15:04:05Z07:00"),
	}

	// Set value based on type, masking secrets
	if c.IsSecret {
		dto.Value = "********"
	} else {
		dto.Value = c.GetValue()
	}

	return dto
}

// ListAll handles GET /api/v1/config
// @Summary List all app configs
// @Description Returns all configuration values (for admin)
// @Tags config
// @Produce json
// @Success 200 {object} AppConfigListResponse
// @Router /api/v1/config [get]
func (h *AppConfigHandler) ListAll(c *gin.Context) {
	configs, err := h.repo.ListAll(c.Request.Context())
	if err != nil {
		h.logger.Error("failed to list configs", zap.Error(err))
		c.JSON(http.StatusInternalServerError, AppConfigListResponse{
			Success: false,
			Message: "Failed to retrieve configs",
		})
		return
	}

	dtos := make([]*AppConfigDTO, len(configs))
	for i, cfg := range configs {
		dtos[i] = h.toDTO(cfg)
	}

	c.JSON(http.StatusOK, AppConfigListResponse{
		Success: true,
		Configs: dtos,
		Total:   len(dtos),
	})
}

// ListByNamespace handles GET /api/v1/config/:namespace
// @Summary List configs by namespace
// @Description Returns all configuration values for a namespace
// @Tags config
// @Produce json
// @Param namespace path string true "Config namespace"
// @Param chain_id query int false "Chain ID (default: 0)"
// @Success 200 {object} AppConfigListResponse
// @Router /api/v1/config/{namespace} [get]
func (h *AppConfigHandler) ListByNamespace(c *gin.Context) {
	namespace := c.Param("namespace")
	chainID := int64(0)
	if chainStr := c.Query("chain_id"); chainStr != "" {
		if id, err := strconv.ParseInt(chainStr, 10, 64); err == nil {
			chainID = id
		}
	}

	configs, err := h.repo.ListByNamespace(c.Request.Context(), namespace, chainID)
	if err != nil {
		h.logger.Error("failed to list configs by namespace",
			zap.String("namespace", namespace),
			zap.Int64("chain_id", chainID),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, AppConfigListResponse{
			Success: false,
			Message: "Failed to retrieve configs",
		})
		return
	}

	dtos := make([]*AppConfigDTO, len(configs))
	for i, cfg := range configs {
		dtos[i] = h.toDTO(cfg)
	}

	c.JSON(http.StatusOK, AppConfigListResponse{
		Success: true,
		Configs: dtos,
		Total:   len(dtos),
	})
}

// GetConfig handles GET /api/v1/config/:namespace/:key
// @Summary Get a specific config
// @Description Returns a single configuration value
// @Tags config
// @Produce json
// @Param namespace path string true "Config namespace"
// @Param key path string true "Config key"
// @Param chain_id query int false "Chain ID (default: uses fallback)"
// @Success 200 {object} AppConfigResponse
// @Failure 404 {object} AppConfigResponse
// @Router /api/v1/config/{namespace}/{key} [get]
func (h *AppConfigHandler) GetConfig(c *gin.Context) {
	namespace := c.Param("namespace")
	key := c.Param("key")
	chainID := int64(0)
	if chainStr := c.Query("chain_id"); chainStr != "" {
		if id, err := strconv.ParseInt(chainStr, 10, 64); err == nil {
			chainID = id
		}
	}

	// Use fallback to try chain-specific first, then global
	config, err := h.repo.GetWithFallback(c.Request.Context(), namespace, key, chainID)
	if err != nil {
		h.logger.Warn("config not found",
			zap.String("namespace", namespace),
			zap.String("key", key),
			zap.Int64("chain_id", chainID),
			zap.Error(err),
		)
		c.JSON(http.StatusNotFound, AppConfigResponse{
			Success: false,
			Message: "Config not found",
		})
		return
	}

	c.JSON(http.StatusOK, AppConfigResponse{
		Success: true,
		Config:  h.toDTO(config),
	})
}

// UpdateConfig handles PUT /api/v1/config/:namespace/:key
// @Summary Update a config
// @Description Updates a configuration value
// @Tags config
// @Accept json
// @Produce json
// @Param namespace path string true "Config namespace"
// @Param key path string true "Config key"
// @Param chain_id query int false "Chain ID (default: 0)"
// @Param request body AppConfigUpdateRequest true "Update request"
// @Success 200 {object} AppConfigResponse
// @Failure 400 {object} AppConfigResponse
// @Failure 404 {object} AppConfigResponse
// @Router /api/v1/config/{namespace}/{key} [put]
func (h *AppConfigHandler) UpdateConfig(c *gin.Context) {
	namespace := c.Param("namespace")
	key := c.Param("key")
	chainID := int64(0)
	if chainStr := c.Query("chain_id"); chainStr != "" {
		if id, err := strconv.ParseInt(chainStr, 10, 64); err == nil {
			chainID = id
		}
	}

	var req AppConfigUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, AppConfigResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Get existing config to determine value type
	existing, err := h.repo.Get(c.Request.Context(), namespace, key, chainID)
	if err != nil {
		c.JSON(http.StatusNotFound, AppConfigResponse{
			Success: false,
			Message: "Config not found",
		})
		return
	}

	// Build update based on value type
	update := &repository.AppConfigUpdate{
		UpdatedBy:   req.UpdatedBy,
		Description: req.Description,
	}

	switch existing.ValueType {
	case "string", "address", "json":
		if strVal, ok := req.Value.(string); ok {
			update.ValueString = &strVal
		}
	case "number":
		switch v := req.Value.(type) {
		case float64:
			i := int64(v)
			update.ValueNumber = &i
		case int64:
			update.ValueNumber = &v
		}
	case "wei":
		switch v := req.Value.(type) {
		case string:
			wei, ok := new(big.Int).SetString(v, 10)
			if ok {
				update.ValueWei = wei
			}
		case float64:
			update.ValueWei = big.NewInt(int64(v))
		}
	case "boolean":
		if boolVal, ok := req.Value.(bool); ok {
			update.ValueBoolean = &boolVal
		}
	}

	if err := h.repo.Update(c.Request.Context(), namespace, key, chainID, update); err != nil {
		h.logger.Error("failed to update config",
			zap.String("namespace", namespace),
			zap.String("key", key),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, AppConfigResponse{
			Success: false,
			Message: "Failed to update config",
		})
		return
	}

	// Fetch updated config
	updated, _ := h.repo.Get(c.Request.Context(), namespace, key, chainID)

	h.logger.Info("config updated",
		zap.String("namespace", namespace),
		zap.String("key", key),
		zap.Int64("chain_id", chainID),
		zap.String("updated_by", req.UpdatedBy),
	)

	c.JSON(http.StatusOK, AppConfigResponse{
		Success: true,
		Config:  h.toDTO(updated),
		Message: "Config updated successfully",
	})
}

// CreateConfig handles POST /api/v1/config
// @Summary Create a new config
// @Description Creates a new configuration value
// @Tags config
// @Accept json
// @Produce json
// @Param request body AppConfigCreateRequest true "Create request"
// @Success 201 {object} AppConfigResponse
// @Failure 400 {object} AppConfigResponse
// @Router /api/v1/config [post]
func (h *AppConfigHandler) CreateConfig(c *gin.Context) {
	var req AppConfigCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, AppConfigResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate value type
	validTypes := map[string]bool{
		"string": true, "number": true, "wei": true, "address": true, "boolean": true, "json": true,
	}
	if !validTypes[req.ValueType] {
		c.JSON(http.StatusBadRequest, AppConfigResponse{
			Success: false,
			Message: "Invalid value_type. Must be: string, number, wei, address, boolean, or json",
		})
		return
	}

	// Build create struct
	create := &repository.AppConfigCreate{
		Namespace:   req.Namespace,
		ConfigKey:   req.ConfigKey,
		ValueType:   req.ValueType,
		Description: req.Description,
		IsSecret:    req.IsSecret,
		ChainID:     req.ChainID,
		UpdatedBy:   req.UpdatedBy,
	}

	// Set value based on type
	switch req.ValueType {
	case "string", "address", "json":
		if strVal, ok := req.Value.(string); ok {
			create.ValueString = &strVal
		}
	case "number":
		switch v := req.Value.(type) {
		case float64:
			i := int64(v)
			create.ValueNumber = &i
		case int64:
			create.ValueNumber = &v
		}
	case "wei":
		switch v := req.Value.(type) {
		case string:
			create.ValueWei, _ = new(big.Int).SetString(v, 10)
		case float64:
			create.ValueWei = big.NewInt(int64(v))
		}
	case "boolean":
		if boolVal, ok := req.Value.(bool); ok {
			create.ValueBoolean = &boolVal
		}
	}

	if err := h.repo.Create(c.Request.Context(), create); err != nil {
		h.logger.Error("failed to create config",
			zap.String("namespace", req.Namespace),
			zap.String("key", req.ConfigKey),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, AppConfigResponse{
			Success: false,
			Message: "Failed to create config",
		})
		return
	}

	// Fetch created config
	created, _ := h.repo.Get(c.Request.Context(), req.Namespace, req.ConfigKey, req.ChainID)

	h.logger.Info("config created",
		zap.String("namespace", req.Namespace),
		zap.String("key", req.ConfigKey),
		zap.Int64("chain_id", req.ChainID),
	)

	c.JSON(http.StatusCreated, AppConfigResponse{
		Success: true,
		Config:  h.toDTO(created),
		Message: "Config created successfully",
	})
}

// DeleteConfig handles DELETE /api/v1/config/:namespace/:key
// @Summary Delete a config
// @Description Soft-deletes a configuration value
// @Tags config
// @Produce json
// @Param namespace path string true "Config namespace"
// @Param key path string true "Config key"
// @Param chain_id query int false "Chain ID (default: 0)"
// @Param deleted_by query string true "Address of deleter"
// @Success 200 {object} AppConfigResponse
// @Failure 404 {object} AppConfigResponse
// @Router /api/v1/config/{namespace}/{key} [delete]
func (h *AppConfigHandler) DeleteConfig(c *gin.Context) {
	namespace := c.Param("namespace")
	key := c.Param("key")
	chainID := int64(0)
	if chainStr := c.Query("chain_id"); chainStr != "" {
		if id, err := strconv.ParseInt(chainStr, 10, 64); err == nil {
			chainID = id
		}
	}
	deletedBy := c.Query("deleted_by")
	if deletedBy == "" {
		c.JSON(http.StatusBadRequest, AppConfigResponse{
			Success: false,
			Message: "deleted_by query parameter is required",
		})
		return
	}

	if err := h.repo.Delete(c.Request.Context(), namespace, key, chainID, deletedBy); err != nil {
		h.logger.Warn("failed to delete config",
			zap.String("namespace", namespace),
			zap.String("key", key),
			zap.Error(err),
		)
		c.JSON(http.StatusNotFound, AppConfigResponse{
			Success: false,
			Message: "Config not found",
		})
		return
	}

	h.logger.Info("config deleted",
		zap.String("namespace", namespace),
		zap.String("key", key),
		zap.Int64("chain_id", chainID),
		zap.String("deleted_by", deletedBy),
	)

	c.JSON(http.StatusOK, AppConfigResponse{
		Success: true,
		Message: "Config deleted successfully",
	})
}

// GetConfigHistory handles GET /api/v1/config/:namespace/:key/history
// @Summary Get config history
// @Description Returns change history for a configuration value
// @Tags config
// @Produce json
// @Param namespace path string true "Config namespace"
// @Param key path string true "Config key"
// @Param chain_id query int false "Chain ID (default: 0)"
// @Param limit query int false "Number of history entries (default: 20)"
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/config/{namespace}/{key}/history [get]
func (h *AppConfigHandler) GetConfigHistory(c *gin.Context) {
	namespace := c.Param("namespace")
	key := c.Param("key")
	chainID := int64(0)
	if chainStr := c.Query("chain_id"); chainStr != "" {
		if id, err := strconv.ParseInt(chainStr, 10, 64); err == nil {
			chainID = id
		}
	}
	limit := 20
	if limitStr := c.Query("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 {
			limit = l
		}
	}

	history, err := h.repo.GetHistory(c.Request.Context(), namespace, key, chainID, limit)
	if err != nil {
		h.logger.Error("failed to get config history",
			zap.String("namespace", namespace),
			zap.String("key", key),
			zap.Error(err),
		)
		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Failed to retrieve config history",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"history": history,
		"total":   len(history),
	})
}
