package handlers

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"math/big"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/colemanwhaylon/nexus-protocol/backend/internal/repository"
	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// GovernanceHandler handles governance-related API endpoints
type GovernanceHandler struct {
	logger     *zap.Logger
	configRepo repository.GovernanceConfigRepository
	chainID    int64
	mu         sync.RWMutex
	proposals  map[string]*Proposal
	votes      map[string]map[string]*Vote // proposalID -> voterAddress -> Vote
	// Governance parameters (cached from database)
	votingDelay       time.Duration // Delay before voting starts
	votingPeriod      time.Duration // How long voting lasts
	quorumPercent     uint64        // Quorum percentage (e.g., 4 = 4%)
	proposalThreshold *big.Int      // Minimum tokens to create proposal
	timelockDelay     time.Duration // Timelock execution delay
}

// ProposalState represents the state of a proposal
type ProposalState string

const (
	ProposalStatePending   ProposalState = "pending"
	ProposalStateActive    ProposalState = "active"
	ProposalStateCanceled  ProposalState = "canceled"
	ProposalStateDefeated  ProposalState = "defeated"
	ProposalStateSucceeded ProposalState = "succeeded"
	ProposalStateQueued    ProposalState = "queued"
	ProposalStateExpired   ProposalState = "expired"
	ProposalStateExecuted  ProposalState = "executed"
)

// VoteType represents the type of vote
type VoteType uint8

const (
	VoteAgainst VoteType = 0
	VoteFor     VoteType = 1
	VoteAbstain VoteType = 2
)

// Proposal represents a governance proposal
type Proposal struct {
	ID           string        `json:"id"`
	Proposer     string        `json:"proposer"`
	Title        string        `json:"title"`
	Description  string        `json:"description"`
	Targets      []string      `json:"targets"`
	Values       []string      `json:"values"`
	Calldatas    []string      `json:"calldatas"`
	StartTime    time.Time     `json:"start_time"`
	EndTime      time.Time     `json:"end_time"`
	State        ProposalState `json:"state"`
	ForVotes     string        `json:"for_votes"`
	AgainstVotes string        `json:"against_votes"`
	AbstainVotes string        `json:"abstain_votes"`
	CreatedAt    time.Time     `json:"created_at"`
	ExecutedAt   *time.Time    `json:"executed_at,omitempty"`
	CanceledAt   *time.Time    `json:"canceled_at,omitempty"`
	QueuedAt     *time.Time    `json:"queued_at,omitempty"`
	Eta          *time.Time    `json:"eta,omitempty"` // Timelock execution time
}

// Vote represents a vote on a proposal
type Vote struct {
	Voter      string   `json:"voter"`
	ProposalID string   `json:"proposal_id"`
	Support    VoteType `json:"support"`
	Weight     string   `json:"weight"`
	Reason     string   `json:"reason,omitempty"`
	VotedAt    time.Time `json:"voted_at"`
}

// CreateProposalRequest represents a proposal creation request
type CreateProposalRequest struct {
	Proposer    string   `json:"proposer" binding:"required"`
	Title       string   `json:"title" binding:"required"`
	Description string   `json:"description" binding:"required"`
	Targets     []string `json:"targets" binding:"required"`
	Values      []string `json:"values" binding:"required"`
	Calldatas   []string `json:"calldatas" binding:"required"`
}

// CreateProposalResponse represents a proposal creation response
type CreateProposalResponse struct {
	Success    bool      `json:"success"`
	ProposalID string    `json:"proposal_id,omitempty"`
	Proposal   *Proposal `json:"proposal,omitempty"`
	Message    string    `json:"message"`
}

// CastVoteRequest represents a vote casting request
type CastVoteRequest struct {
	Voter      string   `json:"voter" binding:"required"`
	ProposalID string   `json:"proposal_id" binding:"required"`
	Support    VoteType `json:"support" binding:"required"`
	Reason     string   `json:"reason,omitempty"`
	Weight     string   `json:"weight,omitempty"` // For demo, can be specified; in prod would be from snapshot
}

// CastVoteResponse represents a vote casting response
type CastVoteResponse struct {
	Success       bool   `json:"success"`
	TransactionID string `json:"transaction_id,omitempty"`
	Vote          *Vote  `json:"vote,omitempty"`
	Message       string `json:"message"`
}

// ProposalResponse wraps a single proposal response
type ProposalResponse struct {
	Success  bool      `json:"success"`
	Proposal *Proposal `json:"proposal,omitempty"`
	Message  string    `json:"message,omitempty"`
}

// ProposalsListResponse wraps a list of proposals response
type ProposalsListResponse struct {
	Success   bool        `json:"success"`
	Proposals []*Proposal `json:"proposals"`
	Total     int         `json:"total"`
	Page      int         `json:"page"`
	PageSize  int         `json:"page_size"`
}

// VotesListResponse wraps a list of votes for a proposal
type VotesListResponse struct {
	Success    bool    `json:"success"`
	Votes      []*Vote `json:"votes"`
	Total      int     `json:"total"`
	ProposalID string  `json:"proposal_id"`
}

// GovernanceParamsResponse contains governance parameters
type GovernanceParamsResponse struct {
	Success           bool   `json:"success"`
	VotingDelay       string `json:"voting_delay"`
	VotingPeriod      string `json:"voting_period"`
	QuorumPercent     uint64 `json:"quorum_percent"`
	ProposalThreshold string `json:"proposal_threshold"`
	TimelockDelay     string `json:"timelock_delay"`
}

// NewGovernanceHandler creates a new governance handler
func NewGovernanceHandler(logger *zap.Logger, configRepo repository.GovernanceConfigRepository, chainID int64) *GovernanceHandler {
	// Default values (fallback if database unavailable)
	threshold, _ := new(big.Int).SetString("100000000000000000000", 10) // 100 tokens with 18 decimals (demo-friendly)

	h := &GovernanceHandler{
		logger:            logger,
		configRepo:        configRepo,
		chainID:           chainID,
		proposals:         make(map[string]*Proposal),
		votes:             make(map[string]map[string]*Vote),
		votingDelay:       1 * time.Minute,       // 1 minute delay (demo-friendly)
		votingPeriod:      10 * time.Minute,      // 10 minutes voting period (demo-friendly)
		quorumPercent:     4,                     // 4% quorum
		proposalThreshold: threshold,
		timelockDelay:     1 * time.Minute,       // 1 minute timelock (demo-friendly)
	}

	// Load configuration from database
	h.loadConfigFromDatabase()

	// Seed demo proposals
	h.seedDemoProposals()

	return h
}

// loadConfigFromDatabase loads governance parameters from the database
func (h *GovernanceHandler) loadConfigFromDatabase() {
	if h.configRepo == nil {
		h.logger.Warn("config repository not available, using default values")
		return
	}

	ctx, cancel := contextWithTimeout()
	defer cancel()

	configs, err := h.configRepo.ListConfigs(ctx, h.chainID, true)
	if err != nil {
		h.logger.Warn("failed to load governance configs from database, using defaults",
			zap.Error(err),
			zap.Int64("chain_id", h.chainID),
		)
		return
	}

	for _, config := range configs {
		switch config.ConfigKey {
		case "proposal_threshold":
			if config.ValueWei != nil {
				h.proposalThreshold = config.ValueWei
				h.logger.Info("loaded proposal_threshold from database",
					zap.String("value", config.GetDisplayValue()),
				)
			}
		case "voting_delay":
			if config.ValueNumber != nil {
				// Value is in blocks, convert to time (assuming ~12s per block)
				h.votingDelay = time.Duration(*config.ValueNumber) * 12 * time.Second
				h.logger.Info("loaded voting_delay from database",
					zap.String("value", config.GetDisplayValue()),
				)
			}
		case "voting_period":
			if config.ValueNumber != nil {
				// Value is in blocks, convert to time (assuming ~12s per block)
				h.votingPeriod = time.Duration(*config.ValueNumber) * 12 * time.Second
				h.logger.Info("loaded voting_period from database",
					zap.String("value", config.GetDisplayValue()),
				)
			}
		case "quorum_percent":
			if config.ValuePercent != nil {
				h.quorumPercent = uint64(*config.ValuePercent)
				h.logger.Info("loaded quorum_percent from database",
					zap.String("value", config.GetDisplayValue()),
				)
			}
		case "timelock_delay":
			if config.ValueNumber != nil {
				// Value is in seconds
				h.timelockDelay = time.Duration(*config.ValueNumber) * time.Second
				h.logger.Info("loaded timelock_delay from database",
					zap.String("value", config.GetDisplayValue()),
				)
			}
		}
	}

	h.logger.Info("governance config loaded from database",
		zap.Int64("chain_id", h.chainID),
		zap.Int("configs_loaded", len(configs)),
	)
}

// contextWithTimeout returns a context with a default timeout
func contextWithTimeout() (context.Context, context.CancelFunc) {
	return context.WithTimeout(context.Background(), 5*time.Second)
}

// seedDemoProposals initializes demo proposals for testing
func (h *GovernanceHandler) seedDemoProposals() {
	now := time.Now()

	// Active proposal
	activeProposal := &Proposal{
		ID:           h.generateProposalID("0x0000000000000000000000000000000000000001", "Increase Staking Rewards", now.Add(-2*time.Hour)),
		Proposer:     "0x0000000000000000000000000000000000000001",
		Title:        "Increase Staking Rewards from 10% to 12% APY",
		Description:  "This proposal aims to increase staking rewards to incentivize more participation in network security. The increase from 10% to 12% APY will be funded from the treasury reserve allocation.",
		Targets:      []string{"0xStakingContract"},
		Values:       []string{"0"},
		Calldatas:    []string{"0x...setRewardRate(1200)"},
		StartTime:    now.Add(-1 * time.Hour),
		EndTime:      now.Add(6 * 24 * time.Hour),
		State:        ProposalStateActive,
		ForVotes:     "5000000000000000000000000",
		AgainstVotes: "1000000000000000000000000",
		AbstainVotes: "500000000000000000000000",
		CreatedAt:    now.Add(-2 * time.Hour),
	}
	h.proposals[activeProposal.ID] = activeProposal
	h.votes[activeProposal.ID] = make(map[string]*Vote)

	// Succeeded proposal
	succeededProposal := &Proposal{
		ID:           h.generateProposalID("0x0000000000000000000000000000000000000002", "Treasury Allocation", now.Add(-10*24*time.Hour)),
		Proposer:     "0x0000000000000000000000000000000000000002",
		Title:        "Allocate 1M NXS for Developer Grants",
		Description:  "Allocate 1,000,000 NXS tokens from the treasury to fund developer grants and ecosystem growth initiatives.",
		Targets:      []string{"0xTreasuryContract"},
		Values:       []string{"0"},
		Calldatas:    []string{"0x...transfer(grants, 1000000)"},
		StartTime:    now.Add(-9 * 24 * time.Hour),
		EndTime:      now.Add(-2 * 24 * time.Hour),
		State:        ProposalStateSucceeded,
		ForVotes:     "10000000000000000000000000",
		AgainstVotes: "2000000000000000000000000",
		AbstainVotes: "1000000000000000000000000",
		CreatedAt:    now.Add(-10 * 24 * time.Hour),
	}
	h.proposals[succeededProposal.ID] = succeededProposal
	h.votes[succeededProposal.ID] = make(map[string]*Vote)
}

// generateProposalID generates a unique proposal ID
func (h *GovernanceHandler) generateProposalID(proposer, title string, timestamp time.Time) string {
	data := proposer + title + timestamp.String()
	hash := sha256.Sum256([]byte(data))
	return "0x" + hex.EncodeToString(hash[:])
}

// CreateProposal handles POST /api/v1/governance/proposals
// @Summary Create a governance proposal
// @Description Creates a new governance proposal
// @Tags governance
// @Accept json
// @Produce json
// @Param request body CreateProposalRequest true "Create proposal request"
// @Success 200 {object} CreateProposalResponse
// @Failure 400 {object} CreateProposalResponse
// @Router /api/v1/governance/proposals [post]
func (h *GovernanceHandler) CreateProposal(c *gin.Context) {
	var req CreateProposalRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid create proposal request", zap.Error(err))
		c.JSON(http.StatusBadRequest, CreateProposalResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate proposer address
	if !isValidAddress(req.Proposer) {
		c.JSON(http.StatusBadRequest, CreateProposalResponse{
			Success: false,
			Message: "Invalid proposer address format",
		})
		return
	}

	// Validate arrays have same length
	if len(req.Targets) != len(req.Values) || len(req.Values) != len(req.Calldatas) {
		c.JSON(http.StatusBadRequest, CreateProposalResponse{
			Success: false,
			Message: "Targets, values, and calldatas must have the same length",
		})
		return
	}

	// Validate at least one action
	if len(req.Targets) == 0 {
		c.JSON(http.StatusBadRequest, CreateProposalResponse{
			Success: false,
			Message: "Proposal must include at least one action",
		})
		return
	}

	// In production, would verify:
	// 1. Proposer has sufficient voting power (proposal threshold)
	// 2. No duplicate proposals
	// 3. Valid target addresses
	// For demo, we accept the proposal

	now := time.Now()
	proposer := strings.ToLower(req.Proposer)

	proposal := &Proposal{
		ID:           h.generateProposalID(proposer, req.Title, now),
		Proposer:     proposer,
		Title:        req.Title,
		Description:  req.Description,
		Targets:      req.Targets,
		Values:       req.Values,
		Calldatas:    req.Calldatas,
		StartTime:    now.Add(h.votingDelay),
		EndTime:      now.Add(h.votingDelay + h.votingPeriod),
		State:        ProposalStatePending,
		ForVotes:     "0",
		AgainstVotes: "0",
		AbstainVotes: "0",
		CreatedAt:    now,
	}

	h.mu.Lock()
	h.proposals[proposal.ID] = proposal
	h.votes[proposal.ID] = make(map[string]*Vote)
	h.mu.Unlock()

	h.logger.Info("proposal created",
		zap.String("proposal_id", proposal.ID),
		zap.String("proposer", proposer),
		zap.String("title", req.Title),
	)

	c.JSON(http.StatusOK, CreateProposalResponse{
		Success:    true,
		ProposalID: proposal.ID,
		Proposal:   proposal,
		Message:    "Proposal created successfully. Voting will begin in " + h.votingDelay.String(),
	})
}

// GetProposal handles GET /api/v1/governance/proposals/:id
// @Summary Get a proposal by ID
// @Description Returns proposal details for the given ID
// @Tags governance
// @Produce json
// @Param id path string true "Proposal ID"
// @Success 200 {object} ProposalResponse
// @Failure 404 {object} ProposalResponse
// @Router /api/v1/governance/proposals/{id} [get]
func (h *GovernanceHandler) GetProposal(c *gin.Context) {
	proposalID := c.Param("id")

	h.mu.RLock()
	proposal, exists := h.proposals[proposalID]
	h.mu.RUnlock()

	if !exists {
		c.JSON(http.StatusNotFound, ProposalResponse{
			Success: false,
			Message: "Proposal not found",
		})
		return
	}

	// Update state based on current time
	h.updateProposalState(proposal)

	h.logger.Debug("proposal retrieved",
		zap.String("proposal_id", proposalID),
		zap.String("state", string(proposal.State)),
	)

	c.JSON(http.StatusOK, ProposalResponse{
		Success:  true,
		Proposal: proposal,
	})
}

// ListProposals handles GET /api/v1/governance/proposals
// @Summary List all proposals
// @Description Returns a paginated list of governance proposals
// @Tags governance
// @Produce json
// @Param page query int false "Page number (default: 1)"
// @Param page_size query int false "Page size (default: 10, max: 100)"
// @Param state query string false "Filter by state"
// @Success 200 {object} ProposalsListResponse
// @Router /api/v1/governance/proposals [get]
func (h *GovernanceHandler) ListProposals(c *gin.Context) {
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "10"))
	stateFilter := c.Query("state")

	if page < 1 {
		page = 1
	}
	if pageSize < 1 || pageSize > 100 {
		pageSize = 10
	}

	h.mu.RLock()
	var allProposals []*Proposal
	for _, proposal := range h.proposals {
		h.updateProposalState(proposal)
		if stateFilter == "" || string(proposal.State) == stateFilter {
			allProposals = append(allProposals, proposal)
		}
	}
	h.mu.RUnlock()

	// Sort by created_at descending
	sort.Slice(allProposals, func(i, j int) bool {
		return allProposals[i].CreatedAt.After(allProposals[j].CreatedAt)
	})

	// Paginate
	total := len(allProposals)
	start := (page - 1) * pageSize
	end := start + pageSize

	if start >= total {
		c.JSON(http.StatusOK, ProposalsListResponse{
			Success:   true,
			Proposals: []*Proposal{},
			Total:     total,
			Page:      page,
			PageSize:  pageSize,
		})
		return
	}

	if end > total {
		end = total
	}

	c.JSON(http.StatusOK, ProposalsListResponse{
		Success:   true,
		Proposals: allProposals[start:end],
		Total:     total,
		Page:      page,
		PageSize:  pageSize,
	})
}

// CastVote handles POST /api/v1/governance/vote
// @Summary Cast a vote on a proposal
// @Description Casts a vote (for, against, or abstain) on an active proposal
// @Tags governance
// @Accept json
// @Produce json
// @Param request body CastVoteRequest true "Cast vote request"
// @Success 200 {object} CastVoteResponse
// @Failure 400 {object} CastVoteResponse
// @Failure 404 {object} CastVoteResponse
// @Router /api/v1/governance/vote [post]
func (h *GovernanceHandler) CastVote(c *gin.Context) {
	var req CastVoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		h.logger.Warn("invalid vote request", zap.Error(err))
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate voter address
	if !isValidAddress(req.Voter) {
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Invalid voter address format",
		})
		return
	}

	// Validate support value
	if req.Support > 2 {
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Invalid support value: must be 0 (against), 1 (for), or 2 (abstain)",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	// Check proposal exists
	proposal, exists := h.proposals[req.ProposalID]
	if !exists {
		c.JSON(http.StatusNotFound, CastVoteResponse{
			Success: false,
			Message: "Proposal not found",
		})
		return
	}

	// Update proposal state
	h.updateProposalState(proposal)

	// Check proposal is active
	if proposal.State != ProposalStateActive {
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Proposal is not active for voting. Current state: " + string(proposal.State),
		})
		return
	}

	voter := strings.ToLower(req.Voter)

	// Check if already voted
	if _, hasVoted := h.votes[req.ProposalID][voter]; hasVoted {
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Address has already voted on this proposal",
		})
		return
	}

	// Determine vote weight (in production, would be from snapshot)
	weight := req.Weight
	if weight == "" {
		weight = "1000000000000000000000" // Default 1000 tokens for demo
	}

	// Validate weight
	weightInt, ok := new(big.Int).SetString(weight, 10)
	if !ok || weightInt.Sign() <= 0 {
		c.JSON(http.StatusBadRequest, CastVoteResponse{
			Success: false,
			Message: "Invalid vote weight",
		})
		return
	}

	// Record vote
	vote := &Vote{
		Voter:      voter,
		ProposalID: req.ProposalID,
		Support:    req.Support,
		Weight:     weight,
		Reason:     req.Reason,
		VotedAt:    time.Now(),
	}
	h.votes[req.ProposalID][voter] = vote

	// Update vote totals
	switch req.Support {
	case VoteFor:
		forVotes, _ := new(big.Int).SetString(proposal.ForVotes, 10)
		proposal.ForVotes = new(big.Int).Add(forVotes, weightInt).String()
	case VoteAgainst:
		againstVotes, _ := new(big.Int).SetString(proposal.AgainstVotes, 10)
		proposal.AgainstVotes = new(big.Int).Add(againstVotes, weightInt).String()
	case VoteAbstain:
		abstainVotes, _ := new(big.Int).SetString(proposal.AbstainVotes, 10)
		proposal.AbstainVotes = new(big.Int).Add(abstainVotes, weightInt).String()
	}

	h.logger.Info("vote cast",
		zap.String("proposal_id", req.ProposalID),
		zap.String("voter", voter),
		zap.Uint8("support", uint8(req.Support)),
		zap.String("weight", weight),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, CastVoteResponse{
		Success:       true,
		TransactionID: txID,
		Vote:          vote,
		Message:       "Vote cast successfully",
	})
}

// GetVotes handles GET /api/v1/governance/proposals/:id/votes
// @Summary Get votes for a proposal
// @Description Returns all votes cast on a proposal
// @Tags governance
// @Produce json
// @Param id path string true "Proposal ID"
// @Success 200 {object} VotesListResponse
// @Failure 404 {object} VotesListResponse
// @Router /api/v1/governance/proposals/{id}/votes [get]
func (h *GovernanceHandler) GetVotes(c *gin.Context) {
	proposalID := c.Param("id")

	h.mu.RLock()
	defer h.mu.RUnlock()

	if _, exists := h.proposals[proposalID]; !exists {
		c.JSON(http.StatusNotFound, VotesListResponse{
			Success:    false,
			ProposalID: proposalID,
		})
		return
	}

	proposalVotes := h.votes[proposalID]
	votes := make([]*Vote, 0, len(proposalVotes))
	for _, vote := range proposalVotes {
		votes = append(votes, vote)
	}

	// Sort by voted_at descending
	sort.Slice(votes, func(i, j int) bool {
		return votes[i].VotedAt.After(votes[j].VotedAt)
	})

	c.JSON(http.StatusOK, VotesListResponse{
		Success:    true,
		Votes:      votes,
		Total:      len(votes),
		ProposalID: proposalID,
	})
}

// GetVotingPower handles GET /api/v1/governance/voting-power/:address
// @Summary Get voting power for an address
// @Description Returns the voting power for an address at the current block
// @Tags governance
// @Produce json
// @Param address path string true "Ethereum address"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/governance/voting-power/{address} [get]
func (h *GovernanceHandler) GetVotingPower(c *gin.Context) {
	address := c.Param("address")

	if !isValidAddress(address) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid Ethereum address format",
		})
		return
	}

	// In production, would query voting power from snapshot
	// For demo, return mock voting power
	address = strings.ToLower(address)
	votingPower := "1000000000000000000000" // 1000 tokens for demo

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"address":      address,
		"voting_power": votingPower,
		"delegated_to": address, // Self-delegated by default
		"timestamp":    time.Now().UTC().Format(time.RFC3339),
	})
}

// GetGovernanceParams handles GET /api/v1/governance/params
// @Summary Get governance parameters
// @Description Returns current governance configuration parameters
// @Tags governance
// @Produce json
// @Success 200 {object} GovernanceParamsResponse
// @Router /api/v1/governance/params [get]
func (h *GovernanceHandler) GetGovernanceParams(c *gin.Context) {
	c.JSON(http.StatusOK, GovernanceParamsResponse{
		Success:           true,
		VotingDelay:       h.votingDelay.String(),
		VotingPeriod:      h.votingPeriod.String(),
		QuorumPercent:     h.quorumPercent,
		ProposalThreshold: h.proposalThreshold.String(),
		TimelockDelay:     h.timelockDelay.String(),
	})
}

// QueueProposal handles POST /api/v1/governance/proposals/:id/queue
// @Summary Queue a succeeded proposal
// @Description Queues a succeeded proposal for execution in the timelock
// @Tags governance
// @Produce json
// @Param id path string true "Proposal ID"
// @Success 200 {object} ProposalResponse
// @Failure 400 {object} ProposalResponse
// @Failure 404 {object} ProposalResponse
// @Router /api/v1/governance/proposals/{id}/queue [post]
func (h *GovernanceHandler) QueueProposal(c *gin.Context) {
	proposalID := c.Param("id")

	h.mu.Lock()
	defer h.mu.Unlock()

	proposal, exists := h.proposals[proposalID]
	if !exists {
		c.JSON(http.StatusNotFound, ProposalResponse{
			Success: false,
			Message: "Proposal not found",
		})
		return
	}

	h.updateProposalState(proposal)

	if proposal.State != ProposalStateSucceeded {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Only succeeded proposals can be queued. Current state: " + string(proposal.State),
		})
		return
	}

	now := time.Now()
	eta := now.Add(h.timelockDelay) // Configurable timelock delay
	proposal.State = ProposalStateQueued
	proposal.QueuedAt = &now
	proposal.Eta = &eta

	h.logger.Info("proposal queued",
		zap.String("proposal_id", proposalID),
		zap.Time("eta", eta),
	)

	c.JSON(http.StatusOK, ProposalResponse{
		Success:  true,
		Proposal: proposal,
		Message:  "Proposal queued for execution. ETA: " + eta.Format(time.RFC3339),
	})
}

// ExecuteProposal handles POST /api/v1/governance/proposals/:id/execute
// @Summary Execute a queued proposal
// @Description Executes a queued proposal after timelock delay has passed
// @Tags governance
// @Produce json
// @Param id path string true "Proposal ID"
// @Success 200 {object} ProposalResponse
// @Failure 400 {object} ProposalResponse
// @Failure 404 {object} ProposalResponse
// @Router /api/v1/governance/proposals/{id}/execute [post]
func (h *GovernanceHandler) ExecuteProposal(c *gin.Context) {
	proposalID := c.Param("id")

	h.mu.Lock()
	defer h.mu.Unlock()

	proposal, exists := h.proposals[proposalID]
	if !exists {
		c.JSON(http.StatusNotFound, ProposalResponse{
			Success: false,
			Message: "Proposal not found",
		})
		return
	}

	if proposal.State != ProposalStateQueued {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Only queued proposals can be executed. Current state: " + string(proposal.State),
		})
		return
	}

	// Check timelock has passed
	now := time.Now()
	if proposal.Eta != nil && now.Before(*proposal.Eta) {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Timelock delay has not passed. Wait until: " + proposal.Eta.Format(time.RFC3339),
		})
		return
	}

	// In production, would execute the proposal actions on-chain
	proposal.State = ProposalStateExecuted
	proposal.ExecutedAt = &now

	h.logger.Info("proposal executed",
		zap.String("proposal_id", proposalID),
	)

	c.JSON(http.StatusOK, ProposalResponse{
		Success:  true,
		Proposal: proposal,
		Message:  "Proposal executed successfully",
	})
}

// CancelProposal handles POST /api/v1/governance/proposals/:id/cancel
// @Summary Cancel a proposal
// @Description Cancels a proposal (only by proposer or guardian)
// @Tags governance
// @Accept json
// @Produce json
// @Param id path string true "Proposal ID"
// @Param request body map[string]string true "Canceler address"
// @Success 200 {object} ProposalResponse
// @Failure 400 {object} ProposalResponse
// @Failure 403 {object} ProposalResponse
// @Failure 404 {object} ProposalResponse
// @Router /api/v1/governance/proposals/{id}/cancel [post]
func (h *GovernanceHandler) CancelProposal(c *gin.Context) {
	proposalID := c.Param("id")

	var req struct {
		Canceler string `json:"canceler" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.Canceler) {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Invalid canceler address format",
		})
		return
	}

	h.mu.Lock()
	defer h.mu.Unlock()

	proposal, exists := h.proposals[proposalID]
	if !exists {
		c.JSON(http.StatusNotFound, ProposalResponse{
			Success: false,
			Message: "Proposal not found",
		})
		return
	}

	// Check if already executed
	if proposal.State == ProposalStateExecuted {
		c.JSON(http.StatusBadRequest, ProposalResponse{
			Success: false,
			Message: "Cannot cancel an executed proposal",
		})
		return
	}

	canceler := strings.ToLower(req.Canceler)

	// In production, would verify canceler is proposer or guardian
	// For demo, allow proposer to cancel
	if canceler != proposal.Proposer {
		c.JSON(http.StatusForbidden, ProposalResponse{
			Success: false,
			Message: "Only the proposer can cancel this proposal",
		})
		return
	}

	now := time.Now()
	proposal.State = ProposalStateCanceled
	proposal.CanceledAt = &now

	h.logger.Info("proposal canceled",
		zap.String("proposal_id", proposalID),
		zap.String("canceler", canceler),
	)

	c.JSON(http.StatusOK, ProposalResponse{
		Success:  true,
		Proposal: proposal,
		Message:  "Proposal canceled successfully",
	})
}

// updateProposalState updates proposal state based on current time and votes
func (h *GovernanceHandler) updateProposalState(proposal *Proposal) {
	now := time.Now()

	// Skip if already in terminal state
	switch proposal.State {
	case ProposalStateCanceled, ProposalStateDefeated, ProposalStateExecuted, ProposalStateExpired:
		return
	case ProposalStateQueued:
		// Check for expiration (proposals expire 14 days after ETA)
		if proposal.Eta != nil {
			expirationTime := proposal.Eta.Add(14 * 24 * time.Hour)
			if now.After(expirationTime) {
				proposal.State = ProposalStateExpired
			}
		}
		return
	case ProposalStateSucceeded:
		return
	}

	// Check if pending -> active
	if proposal.State == ProposalStatePending && now.After(proposal.StartTime) {
		proposal.State = ProposalStateActive
	}

	// Check if voting has ended
	if now.After(proposal.EndTime) {
		// Calculate quorum (simplified - in production would check against total supply snapshot)
		forVotes, _ := new(big.Int).SetString(proposal.ForVotes, 10)
		againstVotes, _ := new(big.Int).SetString(proposal.AgainstVotes, 10)
		abstainVotes, _ := new(big.Int).SetString(proposal.AbstainVotes, 10)

		totalVotes := new(big.Int).Add(forVotes, againstVotes)
		totalVotes.Add(totalVotes, abstainVotes)

		// Simplified quorum check (4% of 100M tokens)
		quorum, _ := new(big.Int).SetString("4000000000000000000000000", 10) // 4M tokens

		if totalVotes.Cmp(quorum) < 0 {
			proposal.State = ProposalStateDefeated
		} else if forVotes.Cmp(againstVotes) > 0 {
			proposal.State = ProposalStateSucceeded
		} else {
			proposal.State = ProposalStateDefeated
		}
	}
}

// DelegateRequest represents a delegation request
type DelegateRequest struct {
	From string `json:"from" binding:"required"`
	To   string `json:"to" binding:"required"`
}

// Delegate handles POST /api/v1/governance/delegate
// @Summary Delegate voting power
// @Description Delegates voting power to another address
// @Tags governance
// @Accept json
// @Produce json
// @Param request body DelegateRequest true "Delegate request"
// @Success 200 {object} map[string]interface{}
// @Failure 400 {object} map[string]interface{}
// @Router /api/v1/governance/delegate [post]
func (h *GovernanceHandler) Delegate(c *gin.Context) {
	var req DelegateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request: " + err.Error(),
		})
		return
	}

	if !isValidAddress(req.From) || !isValidAddress(req.To) {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid address format",
		})
		return
	}

	from := strings.ToLower(req.From)
	to := strings.ToLower(req.To)

	// In production, this would submit a delegation transaction
	h.logger.Info("delegation submitted",
		zap.String("from", from),
		zap.String("to", to),
	)

	txID := generateMockTxID()

	c.JSON(http.StatusOK, gin.H{
		"success":        true,
		"transaction_id": txID,
		"from":           from,
		"to":             to,
		"message":        "Voting power delegated successfully",
	})
}

// ========== Governance Config Endpoints ==========

// GovernanceConfigResponse wraps a single config response
type GovernanceConfigResponse struct {
	Success bool                        `json:"success"`
	Config  *repository.GovernanceConfig `json:"config,omitempty"`
	Message string                      `json:"message,omitempty"`
}

// GovernanceConfigListResponse wraps a list of configs response
type GovernanceConfigListResponse struct {
	Success bool                          `json:"success"`
	Configs []*repository.GovernanceConfig `json:"configs"`
	ChainID int64                         `json:"chain_id"`
	Total   int                           `json:"total"`
	Message string                        `json:"message,omitempty"`
}

// GovernanceConfigHistoryResponse wraps a config history response
type GovernanceConfigHistoryResponse struct {
	Success   bool                                     `json:"success"`
	ConfigKey string                                   `json:"config_key"`
	ChainID   int64                                    `json:"chain_id"`
	History   []*repository.GovernanceConfigHistoryEntry `json:"history"`
	Total     int                                      `json:"total"`
	Message   string                                   `json:"message,omitempty"`
}

// UpdateGovernanceConfigRequest represents a config update request
type UpdateGovernanceConfigRequest struct {
	ValueWei     string   `json:"value_wei,omitempty"`     // Wei amount as string
	ValueNumber  *int64   `json:"value_number,omitempty"`  // Numeric value
	ValuePercent *float64 `json:"value_percent,omitempty"` // Percentage value
	ValueString  *string  `json:"value_string,omitempty"`  // String value
	IsActive     *bool    `json:"is_active,omitempty"`     // Active status
	UpdatedBy    string   `json:"updated_by"`              // Admin address
}

// ListGovernanceConfigs handles GET /api/v1/governance/config
// @Summary List all governance configs
// @Description Returns all governance configuration parameters for the current chain
// @Tags governance-config
// @Produce json
// @Param active_only query bool false "Filter to active configs only (default: true)"
// @Success 200 {object} GovernanceConfigListResponse
// @Router /api/v1/governance/config [get]
func (h *GovernanceHandler) ListGovernanceConfigs(c *gin.Context) {
	if h.configRepo == nil {
		c.JSON(http.StatusServiceUnavailable, GovernanceConfigListResponse{
			Success: false,
			Message: "Governance config repository not available",
		})
		return
	}

	activeOnly := c.DefaultQuery("active_only", "true") == "true"

	ctx, cancel := contextWithTimeout()
	defer cancel()

	configs, err := h.configRepo.ListConfigs(ctx, h.chainID, activeOnly)
	if err != nil {
		h.logger.Error("failed to list governance configs", zap.Error(err))
		c.JSON(http.StatusInternalServerError, GovernanceConfigListResponse{
			Success: false,
			Message: "Failed to retrieve governance configs",
		})
		return
	}

	c.JSON(http.StatusOK, GovernanceConfigListResponse{
		Success: true,
		Configs: configs,
		ChainID: h.chainID,
		Total:   len(configs),
	})
}

// GetGovernanceConfig handles GET /api/v1/governance/config/:key
// @Summary Get a governance config by key
// @Description Returns a specific governance configuration parameter
// @Tags governance-config
// @Produce json
// @Param key path string true "Config key (e.g., proposal_threshold)"
// @Success 200 {object} GovernanceConfigResponse
// @Failure 404 {object} GovernanceConfigResponse
// @Router /api/v1/governance/config/{key} [get]
func (h *GovernanceHandler) GetGovernanceConfig(c *gin.Context) {
	if h.configRepo == nil {
		c.JSON(http.StatusServiceUnavailable, GovernanceConfigResponse{
			Success: false,
			Message: "Governance config repository not available",
		})
		return
	}

	configKey := c.Param("key")

	ctx, cancel := contextWithTimeout()
	defer cancel()

	config, err := h.configRepo.GetConfig(ctx, configKey, h.chainID)
	if err != nil {
		if err == repository.ErrGovernanceConfigNotFound {
			c.JSON(http.StatusNotFound, GovernanceConfigResponse{
				Success: false,
				Message: "Governance config not found: " + configKey,
			})
			return
		}
		h.logger.Error("failed to get governance config", zap.Error(err), zap.String("key", configKey))
		c.JSON(http.StatusInternalServerError, GovernanceConfigResponse{
			Success: false,
			Message: "Failed to retrieve governance config",
		})
		return
	}

	c.JSON(http.StatusOK, GovernanceConfigResponse{
		Success: true,
		Config:  config,
	})
}

// UpdateGovernanceConfig handles PUT /api/v1/governance/config/:key
// @Summary Update a governance config
// @Description Updates a governance configuration parameter (admin only)
// @Tags governance-config
// @Accept json
// @Produce json
// @Param key path string true "Config key (e.g., proposal_threshold)"
// @Param request body UpdateGovernanceConfigRequest true "Update config request"
// @Success 200 {object} GovernanceConfigResponse
// @Failure 400 {object} GovernanceConfigResponse
// @Failure 404 {object} GovernanceConfigResponse
// @Router /api/v1/governance/config/{key} [put]
func (h *GovernanceHandler) UpdateGovernanceConfig(c *gin.Context) {
	if h.configRepo == nil {
		c.JSON(http.StatusServiceUnavailable, GovernanceConfigResponse{
			Success: false,
			Message: "Governance config repository not available",
		})
		return
	}

	configKey := c.Param("key")

	var req UpdateGovernanceConfigRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, GovernanceConfigResponse{
			Success: false,
			Message: "Invalid request: " + err.Error(),
		})
		return
	}

	// Validate updater address
	if !isValidAddress(req.UpdatedBy) {
		c.JSON(http.StatusBadRequest, GovernanceConfigResponse{
			Success: false,
			Message: "Invalid updated_by address format",
		})
		return
	}

	// Build update struct
	update := &repository.GovernanceConfigUpdate{
		UpdatedBy:    strings.ToLower(req.UpdatedBy),
		ValueNumber:  req.ValueNumber,
		ValuePercent: req.ValuePercent,
		ValueString:  req.ValueString,
		IsActive:     req.IsActive,
	}

	// Parse wei value if provided
	if req.ValueWei != "" {
		valueWei, ok := new(big.Int).SetString(req.ValueWei, 10)
		if !ok {
			c.JSON(http.StatusBadRequest, GovernanceConfigResponse{
				Success: false,
				Message: "Invalid value_wei format: must be a valid integer string",
			})
			return
		}
		update.ValueWei = valueWei
	}

	ctx, cancel := contextWithTimeout()
	defer cancel()

	err := h.configRepo.UpdateConfig(ctx, configKey, h.chainID, update)
	if err != nil {
		if err == repository.ErrGovernanceConfigNotFound {
			c.JSON(http.StatusNotFound, GovernanceConfigResponse{
				Success: false,
				Message: "Governance config not found: " + configKey,
			})
			return
		}
		h.logger.Error("failed to update governance config",
			zap.Error(err),
			zap.String("key", configKey),
			zap.String("updated_by", req.UpdatedBy),
		)
		c.JSON(http.StatusInternalServerError, GovernanceConfigResponse{
			Success: false,
			Message: "Failed to update governance config",
		})
		return
	}

	// Reload config from database to get updated values
	config, _ := h.configRepo.GetConfig(ctx, configKey, h.chainID)

	// Reload cached values in handler
	h.loadConfigFromDatabase()

	h.logger.Info("governance config updated",
		zap.String("key", configKey),
		zap.String("updated_by", req.UpdatedBy),
		zap.Int64("chain_id", h.chainID),
	)

	c.JSON(http.StatusOK, GovernanceConfigResponse{
		Success: true,
		Config:  config,
		Message: "Governance config updated successfully. Note: Changes need to be synced to smart contract.",
	})
}

// GetGovernanceConfigHistory handles GET /api/v1/governance/config/:key/history
// @Summary Get governance config change history
// @Description Returns the audit trail for a governance configuration parameter
// @Tags governance-config
// @Produce json
// @Param key path string true "Config key (e.g., proposal_threshold)"
// @Param limit query int false "Number of history entries (default: 10, max: 100)"
// @Success 200 {object} GovernanceConfigHistoryResponse
// @Failure 404 {object} GovernanceConfigHistoryResponse
// @Router /api/v1/governance/config/{key}/history [get]
func (h *GovernanceHandler) GetGovernanceConfigHistory(c *gin.Context) {
	if h.configRepo == nil {
		c.JSON(http.StatusServiceUnavailable, GovernanceConfigHistoryResponse{
			Success: false,
			Message: "Governance config repository not available",
		})
		return
	}

	configKey := c.Param("key")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "10"))
	if limit < 1 || limit > 100 {
		limit = 10
	}

	ctx, cancel := contextWithTimeout()
	defer cancel()

	// First check if config exists
	_, err := h.configRepo.GetConfig(ctx, configKey, h.chainID)
	if err != nil {
		if err == repository.ErrGovernanceConfigNotFound {
			c.JSON(http.StatusNotFound, GovernanceConfigHistoryResponse{
				Success: false,
				Message: "Governance config not found: " + configKey,
			})
			return
		}
		c.JSON(http.StatusInternalServerError, GovernanceConfigHistoryResponse{
			Success: false,
			Message: "Failed to retrieve governance config",
		})
		return
	}

	history, err := h.configRepo.GetConfigHistory(ctx, configKey, h.chainID, limit)
	if err != nil {
		h.logger.Error("failed to get governance config history", zap.Error(err), zap.String("key", configKey))
		c.JSON(http.StatusInternalServerError, GovernanceConfigHistoryResponse{
			Success: false,
			Message: "Failed to retrieve config history",
		})
		return
	}

	c.JSON(http.StatusOK, GovernanceConfigHistoryResponse{
		Success:   true,
		ConfigKey: configKey,
		ChainID:   h.chainID,
		History:   history,
		Total:     len(history),
	})
}

// SyncGovernanceConfig handles POST /api/v1/governance/config/:key/sync
// @Summary Sync governance config to smart contract
// @Description Marks a governance config as synced after smart contract update
// @Tags governance-config
// @Accept json
// @Produce json
// @Param key path string true "Config key (e.g., proposal_threshold)"
// @Param request body map[string]string true "Sync request with tx_hash"
// @Success 200 {object} GovernanceConfigResponse
// @Failure 400 {object} GovernanceConfigResponse
// @Failure 404 {object} GovernanceConfigResponse
// @Router /api/v1/governance/config/{key}/sync [post]
func (h *GovernanceHandler) SyncGovernanceConfig(c *gin.Context) {
	if h.configRepo == nil {
		c.JSON(http.StatusServiceUnavailable, GovernanceConfigResponse{
			Success: false,
			Message: "Governance config repository not available",
		})
		return
	}

	configKey := c.Param("key")

	var req struct {
		TxHash string `json:"tx_hash" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, GovernanceConfigResponse{
			Success: false,
			Message: "Invalid request: tx_hash is required",
		})
		return
	}

	// Validate tx hash format (0x + 64 hex characters)
	if len(req.TxHash) != 66 || !strings.HasPrefix(req.TxHash, "0x") {
		c.JSON(http.StatusBadRequest, GovernanceConfigResponse{
			Success: false,
			Message: "Invalid tx_hash format: must be 0x followed by 64 hex characters",
		})
		return
	}

	ctx, cancel := contextWithTimeout()
	defer cancel()

	err := h.configRepo.MarkSynced(ctx, configKey, h.chainID, req.TxHash)
	if err != nil {
		if err == repository.ErrGovernanceConfigNotFound {
			c.JSON(http.StatusNotFound, GovernanceConfigResponse{
				Success: false,
				Message: "Governance config not found: " + configKey,
			})
			return
		}
		h.logger.Error("failed to mark governance config as synced",
			zap.Error(err),
			zap.String("key", configKey),
			zap.String("tx_hash", req.TxHash),
		)
		c.JSON(http.StatusInternalServerError, GovernanceConfigResponse{
			Success: false,
			Message: "Failed to mark config as synced",
		})
		return
	}

	// Get updated config
	config, _ := h.configRepo.GetConfig(ctx, configKey, h.chainID)

	h.logger.Info("governance config marked as synced",
		zap.String("key", configKey),
		zap.String("tx_hash", req.TxHash),
		zap.Int64("chain_id", h.chainID),
	)

	c.JSON(http.StatusOK, GovernanceConfigResponse{
		Success: true,
		Config:  config,
		Message: "Governance config marked as synced with smart contract",
	})
}

// ReloadGovernanceConfig handles POST /api/v1/governance/config/reload
// @Summary Reload governance configs from database
// @Description Reloads all governance configuration from database into memory cache
// @Tags governance-config
// @Produce json
// @Success 200 {object} map[string]interface{}
// @Router /api/v1/governance/config/reload [post]
func (h *GovernanceHandler) ReloadGovernanceConfig(c *gin.Context) {
	h.loadConfigFromDatabase()

	c.JSON(http.StatusOK, gin.H{
		"success":            true,
		"message":            "Governance config reloaded from database",
		"chain_id":           h.chainID,
		"voting_delay":       h.votingDelay.String(),
		"voting_period":      h.votingPeriod.String(),
		"quorum_percent":     h.quorumPercent,
		"proposal_threshold": h.proposalThreshold.String(),
		"timelock_delay":     h.timelockDelay.String(),
	})
}
