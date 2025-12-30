package handlers

import (
	"crypto/sha256"
	"encoding/hex"
	"math/big"
	"net/http"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"go.uber.org/zap"
)

// GovernanceHandler handles governance-related API endpoints
type GovernanceHandler struct {
	logger    *zap.Logger
	mu        sync.RWMutex
	proposals map[string]*Proposal
	votes     map[string]map[string]*Vote // proposalID -> voterAddress -> Vote
	// Governance parameters
	votingDelay    time.Duration // Delay before voting starts
	votingPeriod   time.Duration // How long voting lasts
	quorumPercent  uint64        // Quorum percentage (e.g., 4 = 4%)
	proposalThreshold *big.Int   // Minimum tokens to create proposal
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
func NewGovernanceHandler(logger *zap.Logger) *GovernanceHandler {
	threshold, _ := new(big.Int).SetString("100000000000000000000000", 10) // 100k tokens with 18 decimals

	h := &GovernanceHandler{
		logger:            logger,
		proposals:         make(map[string]*Proposal),
		votes:             make(map[string]map[string]*Vote),
		votingDelay:       1 * time.Hour,  // 1 hour delay before voting starts
		votingPeriod:      7 * 24 * time.Hour, // 7 days voting period
		quorumPercent:     4, // 4% quorum
		proposalThreshold: threshold,
	}

	// Seed demo proposals
	h.seedDemoProposals()

	return h
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
		TimelockDelay:     "48h", // 48 hours timelock delay
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
	eta := now.Add(48 * time.Hour) // 48 hour timelock delay
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
