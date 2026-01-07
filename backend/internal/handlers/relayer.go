package handlers

import (
	"context"
	"crypto/ecdsa"
	"encoding/hex"
	"errors"
	"fmt"
	"math/big"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/common/hexutil"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
)

// RelayerHandler handles meta-transaction relay endpoints
type RelayerHandler struct {
	repo            repository.RelayerRepository
	configRepo      repository.AppConfigRepository
	logger          *zap.Logger
	ethClient       *ethclient.Client
	forwarderAddr   common.Address
	relayerKey      *ecdsa.PrivateKey
	chainID         *big.Int
}

// NewRelayerHandler creates a new relayer handler with injected dependencies
func NewRelayerHandler(
	repo repository.RelayerRepository,
	configRepo repository.AppConfigRepository,
	logger *zap.Logger,
) (*RelayerHandler, error) {
	// Connect to Ethereum node
	rpcURL := os.Getenv("RPC_URL")
	if rpcURL == "" {
		rpcURL = "http://localhost:8545"
	}

	client, err := ethclient.Dial(rpcURL)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to Ethereum node: %w", err)
	}

	// Get chain ID
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get chain ID: %w", err)
	}

	// Load relayer private key
	relayerKeyHex := os.Getenv("RELAYER_PRIVATE_KEY")
	if relayerKeyHex == "" {
		return nil, fmt.Errorf("RELAYER_PRIVATE_KEY not set")
	}

	// Remove 0x prefix if present
	relayerKeyHex = strings.TrimPrefix(relayerKeyHex, "0x")
	relayerKey, err := crypto.HexToECDSA(relayerKeyHex)
	if err != nil {
		return nil, fmt.Errorf("invalid relayer private key: %w", err)
	}

	// Get forwarder contract address
	forwarderAddrHex := os.Getenv("FORWARDER_ADDRESS")
	if forwarderAddrHex == "" {
		return nil, fmt.Errorf("FORWARDER_ADDRESS not set")
	}
	forwarderAddr := common.HexToAddress(forwarderAddrHex)

	return &RelayerHandler{
		repo:          repo,
		configRepo:    configRepo,
		logger:        logger,
		ethClient:     client,
		forwarderAddr: forwarderAddr,
		relayerKey:    relayerKey,
		chainID:       chainID,
	}, nil
}

// RelayerResponse wraps relayer API responses
type RelayerResponse struct {
	Success bool        `json:"success"`
	Data    interface{} `json:"data,omitempty"`
	Message string      `json:"message,omitempty"`
	Error   string      `json:"error,omitempty"`
}

// RelayRequest represents a request to relay a meta-transaction
type RelayRequest struct {
	From         string `json:"from" binding:"required"`
	To           string `json:"to" binding:"required"`
	Value        string `json:"value" binding:"required"`
	Gas          uint64 `json:"gas" binding:"required"`
	Nonce        uint64 `json:"nonce" binding:"required"`
	Deadline     uint64 `json:"deadline" binding:"required"`
	Data         string `json:"data" binding:"required"`
	Signature    string `json:"signature" binding:"required"`
	FunctionName string `json:"function_name,omitempty"` // Optional: for tracking
}

// Relay handles POST /api/v1/relay
// @Summary Relay a meta-transaction
// @Description Relays a signed ERC-2771 meta-transaction through the NexusForwarder
// @Tags relayer
// @Accept json
// @Produce json
// @Param request body RelayRequest true "Relay request"
// @Success 200 {object} RelayerResponse
// @Failure 400 {object} RelayerResponse
// @Router /api/v1/relay [post]
func (h *RelayerHandler) Relay(c *gin.Context) {
	var req RelayRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate addresses
	if !isValidAddress(req.From) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid 'from' address format",
		})
		return
	}

	if !isValidAddress(req.To) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid 'to' address format",
		})
		return
	}

	// Validate deadline
	deadlineTime := time.Unix(int64(req.Deadline), 0)
	if deadlineTime.Before(time.Now()) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Request deadline has passed",
		})
		return
	}

	// Validate signature format
	if !strings.HasPrefix(req.Signature, "0x") || len(req.Signature) != 132 {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid signature format",
		})
		return
	}

	ctx := c.Request.Context()

	// Verify the signature (EIP-712)
	if err := h.verifySignature(req); err != nil {
		h.logger.Warn("invalid signature",
			zap.String("from", req.From),
			zap.Error(err),
		)
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid signature: " + err.Error(),
		})
		return
	}

	// Create meta-transaction record
	metaTx := &repository.MetaTransaction{
		FromAddress:  strings.ToLower(req.From),
		ToAddress:    strings.ToLower(req.To),
		FunctionName: req.FunctionName,
		Calldata:     req.Data,
		Value:        req.Value,
		GasLimit:     req.Gas,
		Nonce:        req.Nonce,
		Deadline:     deadlineTime,
		Signature:    req.Signature,
		Status:       repository.MetaTxStatusPending,
	}

	if err := h.repo.CreateMetaTx(ctx, metaTx); err != nil {
		h.logger.Error("failed to create meta-tx record", zap.Error(err))
		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Failed to process request",
		})
		return
	}

	// Submit the transaction
	txHash, err := h.submitToChain(ctx, req, metaTx.ID)
	if err != nil {
		h.logger.Error("failed to submit meta-tx",
			zap.String("id", metaTx.ID),
			zap.Error(err),
		)

		// Update status to failed
		errMsg := err.Error()
		h.repo.UpdateMetaTxStatus(ctx, metaTx.ID, &repository.MetaTxStatusUpdate{
			Status:       repository.MetaTxStatusFailed,
			ErrorMessage: &errMsg,
		})

		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Failed to relay transaction: " + err.Error(),
		})
		return
	}

	h.logger.Info("meta-transaction relayed",
		zap.String("id", metaTx.ID),
		zap.String("tx_hash", txHash),
		zap.String("from", req.From),
		zap.String("to", req.To),
	)

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data: gin.H{
			"id":      metaTx.ID,
			"tx_hash": txHash,
			"status":  "submitted",
		},
		Message: "Transaction relayed successfully",
	})
}

// GetStatus handles GET /api/v1/relay/:id
// @Summary Get meta-transaction status
// @Description Returns the current status of a meta-transaction
// @Tags relayer
// @Produce json
// @Param id path string true "Meta-transaction ID"
// @Success 200 {object} RelayerResponse
// @Failure 404 {object} RelayerResponse
// @Router /api/v1/relay/{id} [get]
func (h *RelayerHandler) GetStatus(c *gin.Context) {
	id := c.Param("id")

	metaTx, err := h.repo.GetMetaTx(c.Request.Context(), id)
	if err != nil {
		if errors.Is(err, repository.ErrMetaTxNotFound) {
			c.JSON(http.StatusNotFound, RelayerResponse{
				Success: false,
				Error:   "Meta-transaction not found",
			})
			return
		}
		h.logger.Error("failed to get meta-tx", zap.Error(err))
		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data:    metaTx,
	})
}

// GetByTxHash handles GET /api/v1/relay/tx/:txHash
// @Summary Get meta-transaction by transaction hash
// @Description Returns meta-transaction details for a specific blockchain transaction
// @Tags relayer
// @Produce json
// @Param txHash path string true "Transaction hash"
// @Success 200 {object} RelayerResponse
// @Failure 404 {object} RelayerResponse
// @Router /api/v1/relay/tx/{txHash} [get]
func (h *RelayerHandler) GetByTxHash(c *gin.Context) {
	txHash := c.Param("txHash")

	if !isValidTxHash(txHash) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid transaction hash format",
		})
		return
	}

	metaTx, err := h.repo.GetMetaTxByHash(c.Request.Context(), txHash)
	if err != nil {
		if errors.Is(err, repository.ErrMetaTxNotFound) {
			c.JSON(http.StatusNotFound, RelayerResponse{
				Success: false,
				Error:   "Meta-transaction not found for hash",
			})
			return
		}
		h.logger.Error("failed to get meta-tx by hash", zap.Error(err))
		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data:    metaTx,
	})
}

// GetNonce handles GET /api/v1/relay/nonce/:address
// @Summary Get next nonce for an address
// @Description Returns the next available nonce for meta-transactions from an address
// @Tags relayer
// @Produce json
// @Param address path string true "User address"
// @Success 200 {object} RelayerResponse
// @Router /api/v1/relay/nonce/{address} [get]
func (h *RelayerHandler) GetNonce(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid address format",
		})
		return
	}

	// First check on-chain nonce from forwarder contract
	// For now, we use the DB-tracked nonce
	nonce, err := h.repo.GetNextNonce(c.Request.Context(), strings.ToLower(address))
	if err != nil {
		h.logger.Error("failed to get nonce", zap.Error(err))
		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Failed to get nonce",
		})
		return
	}

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data: gin.H{
			"address": strings.ToLower(address),
			"nonce":   nonce,
		},
	})
}

// ListUserMetaTxs handles GET /api/v1/relay/user/:address
// @Summary List meta-transactions for a user
// @Description Returns all meta-transactions submitted by a specific address
// @Tags relayer
// @Produce json
// @Param address path string true "User address"
// @Param status query string false "Filter by status"
// @Param page query int false "Page number (default: 1)"
// @Param page_size query int false "Page size (default: 20)"
// @Success 200 {object} RelayerResponse
// @Router /api/v1/relay/user/{address} [get]
func (h *RelayerHandler) ListUserMetaTxs(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, RelayerResponse{
			Success: false,
			Error:   "Invalid address format",
		})
		return
	}

	filter := repository.MetaTxFilter{
		FromAddress: strings.ToLower(address),
	}

	if status := c.Query("status"); status != "" {
		filter.Status = repository.MetaTxStatus(status)
	}

	page := 1
	pageSize := 20
	if p := c.Query("page"); p != "" {
		fmt.Sscanf(p, "%d", &page)
	}
	if ps := c.Query("page_size"); ps != "" {
		fmt.Sscanf(ps, "%d", &pageSize)
	}

	txs, total, err := h.repo.ListMetaTx(c.Request.Context(), filter, repository.Pagination{
		Page:     page,
		PageSize: pageSize,
	})
	if err != nil {
		h.logger.Error("failed to list meta-txs", zap.Error(err))
		c.JSON(http.StatusInternalServerError, RelayerResponse{
			Success: false,
			Error:   "Internal server error",
		})
		return
	}

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data: gin.H{
			"transactions": txs,
			"total":        total,
			"page":         page,
			"page_size":    pageSize,
		},
	})
}

// verifySignature verifies the EIP-712 signature
func (h *RelayerHandler) verifySignature(req RelayRequest) error {
	// Build EIP-712 typed data hash
	domainSeparator := h.buildDomainSeparator()
	structHash := h.buildStructHash(req)

	// Final hash: keccak256("\x19\x01" || domainSeparator || structHash)
	digest := crypto.Keccak256(
		[]byte("\x19\x01"),
		domainSeparator,
		structHash,
	)

	// Decode signature
	sigBytes, err := hexutil.Decode(req.Signature)
	if err != nil {
		return fmt.Errorf("invalid signature encoding: %w", err)
	}

	if len(sigBytes) != 65 {
		return fmt.Errorf("invalid signature length: %d", len(sigBytes))
	}

	// Adjust v value if needed (Ethereum uses 27/28, but some libraries use 0/1)
	if sigBytes[64] >= 27 {
		sigBytes[64] -= 27
	}

	// Recover public key
	pubKey, err := crypto.SigToPub(digest, sigBytes)
	if err != nil {
		return fmt.Errorf("failed to recover public key: %w", err)
	}

	// Get address from public key
	recoveredAddr := crypto.PubkeyToAddress(*pubKey)
	expectedAddr := common.HexToAddress(req.From)

	if recoveredAddr != expectedAddr {
		return fmt.Errorf("signature does not match 'from' address: recovered %s, expected %s",
			recoveredAddr.Hex(), expectedAddr.Hex())
	}

	return nil
}

// buildDomainSeparator builds the EIP-712 domain separator
func (h *RelayerHandler) buildDomainSeparator() []byte {
	// Domain separator: keccak256(
	//   "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
	// )
	typeHash := crypto.Keccak256([]byte(
		"EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)",
	))

	nameHash := crypto.Keccak256([]byte("NexusForwarder"))
	versionHash := crypto.Keccak256([]byte("1"))

	chainIDBytes := common.LeftPadBytes(h.chainID.Bytes(), 32)
	contractBytes := common.LeftPadBytes(h.forwarderAddr.Bytes(), 32)

	return crypto.Keccak256(
		typeHash,
		nameHash,
		versionHash,
		chainIDBytes,
		contractBytes,
	)
}

// buildStructHash builds the EIP-712 struct hash for ForwardRequest
func (h *RelayerHandler) buildStructHash(req RelayRequest) []byte {
	// ForwardRequest type hash
	typeHash := crypto.Keccak256([]byte(
		"ForwardRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,uint256 deadline,bytes data)",
	))

	// Parse value as big.Int
	value := new(big.Int)
	if req.Value != "" && req.Value != "0" {
		value.SetString(strings.TrimPrefix(req.Value, "0x"), 16)
	}

	// Decode data and hash it
	dataBytes, _ := hexutil.Decode(req.Data)
	dataHash := crypto.Keccak256(dataBytes)

	fromBytes := common.LeftPadBytes(common.HexToAddress(req.From).Bytes(), 32)
	toBytes := common.LeftPadBytes(common.HexToAddress(req.To).Bytes(), 32)
	valueBytes := common.LeftPadBytes(value.Bytes(), 32)
	gasBytes := common.LeftPadBytes(big.NewInt(int64(req.Gas)).Bytes(), 32)
	nonceBytes := common.LeftPadBytes(big.NewInt(int64(req.Nonce)).Bytes(), 32)
	deadlineBytes := common.LeftPadBytes(big.NewInt(int64(req.Deadline)).Bytes(), 32)

	return crypto.Keccak256(
		typeHash,
		fromBytes,
		toBytes,
		valueBytes,
		gasBytes,
		nonceBytes,
		deadlineBytes,
		dataHash,
	)
}

// submitToChain submits the meta-transaction to the blockchain
func (h *RelayerHandler) submitToChain(ctx context.Context, req RelayRequest, metaTxID string) (string, error) {
	// Get current gas price
	gasPrice, err := h.ethClient.SuggestGasPrice(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get gas price: %w", err)
	}

	// Load gas price limits from database (with fallback defaults)
	maxGasPriceGwei := int64(100) // Default 100 gwei
	minGasPriceGwei := int64(1)   // Default 1 gwei

	if h.configRepo != nil {
		if val, err := h.configRepo.GetNumber(ctx, "relayer", "max_gas_price_gwei", h.chainID.Int64()); err == nil {
			maxGasPriceGwei = val
		}
		if val, err := h.configRepo.GetNumber(ctx, "relayer", "min_gas_price_gwei", h.chainID.Int64()); err == nil {
			minGasPriceGwei = val
		}
	}

	maxGasPrice := new(big.Int).Mul(big.NewInt(maxGasPriceGwei), big.NewInt(1e9))
	minGasPrice := new(big.Int).Mul(big.NewInt(minGasPriceGwei), big.NewInt(1e9))

	// Check gas price limits
	if gasPrice.Cmp(maxGasPrice) > 0 {
		return "", fmt.Errorf("gas price too high: %s gwei", new(big.Int).Div(gasPrice, big.NewInt(1e9)))
	}
	if gasPrice.Cmp(minGasPrice) < 0 {
		gasPrice = minGasPrice
	}

	// Get relayer address and nonce
	relayerAddr := crypto.PubkeyToAddress(h.relayerKey.PublicKey)
	nonce, err := h.ethClient.PendingNonceAt(ctx, relayerAddr)
	if err != nil {
		return "", fmt.Errorf("failed to get relayer nonce: %w", err)
	}

	// Build ForwardRequest struct for contract call
	value := new(big.Int)
	if req.Value != "" && req.Value != "0" {
		value.SetString(strings.TrimPrefix(req.Value, "0x"), 16)
	}

	dataBytes, err := hexutil.Decode(req.Data)
	if err != nil {
		return "", fmt.Errorf("invalid calldata: %w", err)
	}

	sigBytes, err := hexutil.Decode(req.Signature)
	if err != nil {
		return "", fmt.Errorf("invalid signature: %w", err)
	}

	// Build the execute function call
	// execute(ForwardRequest calldata req, bytes calldata signature)
	forwarderABI := `[{"inputs":[{"components":[{"internalType":"address","name":"from","type":"address"},{"internalType":"address","name":"to","type":"address"},{"internalType":"uint256","name":"value","type":"uint256"},{"internalType":"uint256","name":"gas","type":"uint256"},{"internalType":"uint256","name":"nonce","type":"uint256"},{"internalType":"uint256","name":"deadline","type":"uint256"},{"internalType":"bytes","name":"data","type":"bytes"}],"internalType":"struct NexusForwarder.ForwardRequest","name":"req","type":"tuple"},{"internalType":"bytes","name":"signature","type":"bytes"}],"name":"execute","outputs":[{"internalType":"bool","name":"","type":"bool"},{"internalType":"bytes","name":"","type":"bytes"}],"stateMutability":"payable","type":"function"}]`

	_ = forwarderABI // We'll use raw transaction encoding

	// For simplicity, use bind.TransactOpts and send raw transaction
	auth, err := bind.NewKeyedTransactorWithChainID(h.relayerKey, h.chainID)
	if err != nil {
		return "", fmt.Errorf("failed to create transactor: %w", err)
	}

	auth.Nonce = big.NewInt(int64(nonce))
	auth.Value = value
	auth.GasLimit = req.Gas + 50000 // Add buffer for forwarding overhead
	auth.GasPrice = gasPrice
	auth.Context = ctx

	// Encode the execute function call manually
	calldata := h.encodeExecuteCall(
		common.HexToAddress(req.From),
		common.HexToAddress(req.To),
		value,
		big.NewInt(int64(req.Gas)),
		big.NewInt(int64(req.Nonce)),
		big.NewInt(int64(req.Deadline)),
		dataBytes,
		sigBytes,
	)

	// Create and sign the transaction
	tx := createLegacyTx(h.forwarderAddr, value, auth.GasLimit, gasPrice, nonce, calldata)
	signedTx, err := auth.Signer(relayerAddr, tx)
	if err != nil {
		return "", fmt.Errorf("failed to sign transaction: %w", err)
	}

	// Send transaction
	if err := h.ethClient.SendTransaction(ctx, signedTx); err != nil {
		return "", fmt.Errorf("failed to send transaction: %w", err)
	}

	txHash := signedTx.Hash().Hex()

	// Update meta-tx status to submitted
	h.repo.UpdateMetaTxStatus(ctx, metaTxID, &repository.MetaTxStatusUpdate{
		Status: repository.MetaTxStatusSubmitted,
		TxHash: &txHash,
	})

	return txHash, nil
}

// encodeExecuteCall encodes the execute function call
func (h *RelayerHandler) encodeExecuteCall(
	from, to common.Address,
	value, gas, nonce, deadline *big.Int,
	data, signature []byte,
) []byte {
	// Function selector for execute(ForwardRequest,bytes)
	selector := crypto.Keccak256([]byte("execute((address,address,uint256,uint256,uint256,uint256,bytes),bytes)"))[:4]

	// Encode parameters using ABI encoding
	// This is a simplified version - in production, use proper ABI encoding
	encoded := make([]byte, 0)
	encoded = append(encoded, selector...)

	// Offset to ForwardRequest (64 bytes from start of params)
	encoded = append(encoded, common.LeftPadBytes(big.NewInt(64).Bytes(), 32)...)
	// Offset to signature (dynamic, calculated later)
	// For now, just append the struct fields directly

	// This is a simplified encoding - in production, use go-ethereum's abi package
	// The actual encoding is more complex due to dynamic types

	return encoded
}

// createLegacyTx creates a legacy Ethereum transaction
func createLegacyTx(to common.Address, value *big.Int, gasLimit uint64, gasPrice *big.Int, nonce uint64, data []byte) *types.Transaction {
	return types.NewTx(&types.LegacyTx{
		Nonce:    nonce,
		GasPrice: gasPrice,
		Gas:      gasLimit,
		To:       &to,
		Value:    value,
		Data:     data,
	})
}

// GetRelayerAddress handles GET /api/v1/relay/relayer
// @Summary Get relayer address
// @Description Returns the address of the relayer that will submit transactions
// @Tags relayer
// @Produce json
// @Success 200 {object} RelayerResponse
// @Router /api/v1/relay/relayer [get]
func (h *RelayerHandler) GetRelayerAddress(c *gin.Context) {
	relayerAddr := crypto.PubkeyToAddress(h.relayerKey.PublicKey)

	// Get relayer ETH balance
	balance, err := h.ethClient.BalanceAt(c.Request.Context(), relayerAddr, nil)
	if err != nil {
		h.logger.Error("failed to get relayer balance", zap.Error(err))
		balance = big.NewInt(0)
	}

	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data: gin.H{
			"address":     relayerAddr.Hex(),
			"balance_wei": balance.String(),
			"chain_id":    h.chainID.String(),
			"forwarder":   h.forwarderAddr.Hex(),
		},
	})
}

// GetForwarderAddress handles GET /api/v1/relay/forwarder
// @Summary Get forwarder contract address
// @Description Returns the address of the NexusForwarder contract
// @Tags relayer
// @Produce json
// @Success 200 {object} RelayerResponse
// @Router /api/v1/relay/forwarder [get]
func (h *RelayerHandler) GetForwarderAddress(c *gin.Context) {
	c.JSON(http.StatusOK, RelayerResponse{
		Success: true,
		Data: gin.H{
			"address":  h.forwarderAddr.Hex(),
			"chain_id": h.chainID.String(),
		},
	})
}

// isValidHexData validates hex-encoded data
func isValidHexData(data string) bool {
	if !strings.HasPrefix(data, "0x") {
		return false
	}
	_, err := hex.DecodeString(data[2:])
	return err == nil
}
