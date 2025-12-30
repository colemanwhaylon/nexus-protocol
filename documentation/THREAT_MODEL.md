# Nexus Protocol Threat Model

## Overview

This document presents a comprehensive threat model for Nexus Protocol using the STRIDE methodology. It identifies potential threats, assesses risks, and documents mitigations.

---

## STRIDE Analysis

### Threat Categories

| Category | Description | Example |
|----------|-------------|---------|
| **S**poofing | Impersonating a user or system | Fake governance proposals |
| **T**ampering | Modifying data or code | Oracle price manipulation |
| **R**epudiation | Denying actions taken | Claiming funds weren't received |
| **I**nformation Disclosure | Exposing sensitive data | Leaking KYC documents |
| **D**enial of Service | Preventing legitimate use | Gas griefing attacks |
| **E**levation of Privilege | Gaining unauthorized access | Bypassing access control |

---

## System Components

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           THREAT SURFACE                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  External                                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Users • Oracles • Relayers • Bridges • DEXs • MEV Bots           │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                        Smart Contracts                             │    │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐    │    │
│  │  │ Token │ │ NFT   │ │Staking│ │Airdrop│ │  Gov  │ │Access │    │    │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘ └───────┘    │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                         Backend Services                           │    │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐               │    │
│  │  │  API  │ │ Cache │ │  DB   │ │Indexer│ │ KYC   │               │    │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                        │
│                                    ▼                                        │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                        Infrastructure                              │    │
│  │  ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐ ┌───────┐               │    │
│  │  │  K8s  │ │  DNS  │ │  CDN  │ │  HSM  │ │ Cloud │               │    │
│  │  └───────┘ └───────┘ └───────┘ └───────┘ └───────┘               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Smart Contract Threats

### T1: Reentrancy Attack

**Category**: Tampering
**Severity**: Critical
**Components**: NexusStaking, RewardsDistributor, NexusAirdrop

**Description**:
Attacker exploits external calls to re-enter contract and drain funds before state updates.

**Attack Vector**:
```solidity
// Vulnerable pattern
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount);
    (bool success, ) = msg.sender.call{value: amount}("");  // External call
    require(success);
    balances[msg.sender] -= amount;  // State update AFTER call
}
```

**Mitigations**:
1. Use ReentrancyGuard (checks-effects-interactions)
2. Update state before external calls
3. Use pull-over-push pattern

**Implementation**:
```solidity
function withdraw(uint256 amount) external nonReentrant {
    require(balances[msg.sender] >= amount);
    balances[msg.sender] -= amount;  // State update FIRST
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success);
}
```

**Risk Score**: Likelihood: Medium | Impact: Critical | Risk: High
**Status**: Mitigated

---

### T2: Oracle Manipulation

**Category**: Tampering
**Severity**: Critical
**Components**: NexusPriceOracle, NexusStaking

**Description**:
Attacker manipulates price oracle to trigger liquidations or steal funds.

**Attack Vectors**:
1. Flash loan to manipulate DEX spot price
2. Chainlink oracle staleness exploitation
3. Multi-block manipulation

**Scenario**:
```
1. Attacker takes flash loan of 1M ETH
2. Swap on Uniswap, manipulating price
3. Exploit protocol using bad price
4. Repay flash loan with profit
```

**Mitigations**:
1. Use TWAP (Time-Weighted Average Price)
2. Multiple oracle sources with median
3. Staleness checks on all price feeds
4. Deviation bounds with circuit breakers
5. Price manipulation detection

**Implementation**:
```solidity
function getPrice(address token) public view returns (uint256) {
    // Chainlink primary
    (, int256 chainlinkPrice, , uint256 updatedAt, ) =
        chainlinkFeed.latestRoundData();

    require(block.timestamp - updatedAt < STALENESS_THRESHOLD, "Stale price");

    // Pyth fallback
    uint256 pythPrice = pythOracle.getPrice(token);

    // Check deviation
    uint256 deviation = calculateDeviation(chainlinkPrice, pythPrice);
    require(deviation < MAX_DEVIATION, "Price deviation too high");

    // Return median
    return median(uint256(chainlinkPrice), pythPrice);
}
```

**Risk Score**: Likelihood: Medium | Impact: Critical | Risk: High
**Status**: Mitigated

---

### T3: Flash Loan Attack

**Category**: Tampering
**Severity**: Critical
**Components**: NexusGovernor, NexusStaking

**Description**:
Attacker uses flash loan to temporarily gain voting power and pass malicious proposal.

**Attack Vector**:
```
1. Take flash loan of tokens
2. Create and vote on malicious proposal (if same-block voting)
3. Execute proposal
4. Repay flash loan
```

**Mitigations**:
1. Snapshot voting power at proposal creation
2. Voting delay (1+ blocks)
3. Time-locked execution
4. Quorum requirements

**Implementation**:
```solidity
function propose(...) external returns (uint256) {
    // Snapshot at previous block
    uint256 proposerVotes = getVotes(msg.sender, block.number - 1);
    require(proposerVotes >= proposalThreshold(), "Below threshold");

    // ...
}

function castVote(uint256 proposalId, uint8 support) public {
    // Use snapshot from proposal creation
    uint256 weight = getVotes(msg.sender, proposals[proposalId].startBlock);
    // ...
}
```

**Risk Score**: Likelihood: Medium | Impact: Critical | Risk: High
**Status**: Mitigated

---

### T4: Access Control Bypass

**Category**: Elevation of Privilege
**Severity**: High
**Components**: All contracts with RBAC

**Description**:
Attacker bypasses role checks to execute privileged functions.

**Attack Vectors**:
1. Missing modifier on function
2. Incorrect role hierarchy
3. Role misconfiguration during deployment

**Mitigations**:
1. Use OpenZeppelin AccessControl
2. Comprehensive test coverage for all roles
3. Deployment verification scripts
4. Regular access control audits

**Implementation**:
```solidity
bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

function pause() external onlyRole(PAUSER_ROLE) {
    _pause();
}

function setConfig(uint256 value) external onlyRole(ADMIN_ROLE) {
    config = value;
}
```

**Risk Score**: Likelihood: Low | Impact: High | Risk: Medium
**Status**: Mitigated

---

### T5: Integer Overflow/Underflow

**Category**: Tampering
**Severity**: High
**Components**: All contracts with math operations

**Description**:
Arithmetic overflow/underflow leads to incorrect calculations.

**Note**: Solidity 0.8+ has built-in overflow protection, but unchecked blocks are vulnerable.

**Mitigations**:
1. Use Solidity 0.8+ (default protection)
2. Careful use of unchecked blocks
3. Fuzz testing for edge cases

**Implementation**:
```solidity
// Safe - protected by default
uint256 total = balance + amount;

// Potentially unsafe - unchecked for gas savings
// Only use when mathematically proven safe
unchecked {
    for (uint256 i = 0; i < length; ++i) {
        // i < length guarantees no overflow
    }
}
```

**Risk Score**: Likelihood: Low | Impact: High | Risk: Low
**Status**: Mitigated

---

### T6: Front-Running / MEV

**Category**: Tampering
**Severity**: Medium
**Components**: NexusAirdrop, DEX interactions

**Description**:
Miners/validators reorder transactions to extract value.

**Attack Vectors**:
1. Sandwich attacks on swaps
2. Front-running airdrop claims
3. Liquidation front-running

**Mitigations**:
1. Commit-reveal schemes
2. Flashbots/MEV protection
3. Slippage protection
4. Private mempools

**Implementation**:
```solidity
// Commit-reveal for sensitive operations
mapping(bytes32 => uint256) public commitments;

function commit(bytes32 hash) external {
    commitments[hash] = block.number;
}

function reveal(bytes32 secret, uint256 amount) external {
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, secret, amount));
    require(commitments[hash] != 0, "No commitment");
    require(block.number > commitments[hash] + 1, "Too early");
    require(block.number < commitments[hash] + 100, "Expired");

    delete commitments[hash];
    _execute(msg.sender, amount);
}
```

**Risk Score**: Likelihood: High | Impact: Medium | Risk: Medium
**Status**: Partially Mitigated

---

### T7: Signature Replay

**Category**: Spoofing
**Severity**: High
**Components**: NexusToken (permit), Meta-transactions

**Description**:
Attacker reuses valid signature on different chain or after nonce reset.

**Mitigations**:
1. Include chain ID in signed data
2. Proper nonce management
3. Deadline/expiry in signatures

**Implementation**:
```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v, bytes32 r, bytes32 s
) external {
    require(block.timestamp <= deadline, "Permit expired");

    bytes32 structHash = keccak256(abi.encode(
        PERMIT_TYPEHASH,
        owner,
        spender,
        value,
        _useNonce(owner),  // Incrementing nonce
        deadline
    ));

    bytes32 hash = _hashTypedDataV4(structHash);  // Includes chain ID
    address signer = ECDSA.recover(hash, v, r, s);
    require(signer == owner, "Invalid signature");

    _approve(owner, spender, value);
}
```

**Risk Score**: Likelihood: Low | Impact: High | Risk: Medium
**Status**: Mitigated

---

### T8: Denial of Service (Gas Griefing)

**Category**: Denial of Service
**Severity**: Medium
**Components**: Batch operations, unbounded loops

**Description**:
Attacker causes functions to run out of gas, preventing legitimate use.

**Attack Vectors**:
1. Fill arrays to cause iteration failure
2. Returndatabomb on callbacks
3. Block stuffing

**Mitigations**:
1. Limit array sizes
2. Use pull-over-push patterns
3. Gas limits on external calls

**Implementation**:
```solidity
uint256 public constant MAX_BATCH_SIZE = 100;

function batchProcess(address[] calldata users) external {
    require(users.length <= MAX_BATCH_SIZE, "Batch too large");

    for (uint256 i = 0; i < users.length;) {
        _process(users[i]);
        unchecked { ++i; }
    }
}

// Pull pattern instead of push
function claimRewards() external {
    uint256 rewards = pendingRewards[msg.sender];
    pendingRewards[msg.sender] = 0;
    token.transfer(msg.sender, rewards);
}
```

**Risk Score**: Likelihood: Medium | Impact: Medium | Risk: Medium
**Status**: Mitigated

---

## Backend/Infrastructure Threats

### T9: API Authentication Bypass

**Category**: Spoofing
**Severity**: High
**Components**: Go API Server

**Description**:
Attacker bypasses JWT authentication to access protected endpoints.

**Attack Vectors**:
1. JWT algorithm confusion (none, HS256 vs RS256)
2. Weak JWT secret
3. Missing signature validation

**Mitigations**:
1. Use RS256 (asymmetric)
2. Validate algorithm explicitly
3. Short token expiration
4. Refresh token rotation

**Implementation**:
```go
func validateJWT(tokenString string) (*Claims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &Claims{}, func(token *jwt.Token) (interface{}, error) {
        // Explicitly check algorithm
        if _, ok := token.Method.(*jwt.SigningMethodRSA); !ok {
            return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
        }
        return publicKey, nil
    })

    if err != nil || !token.Valid {
        return nil, errors.New("invalid token")
    }

    claims, ok := token.Claims.(*Claims)
    if !ok {
        return nil, errors.New("invalid claims")
    }

    return claims, nil
}
```

**Risk Score**: Likelihood: Medium | Impact: High | Risk: High
**Status**: Mitigated

---

### T10: SQL Injection

**Category**: Tampering
**Severity**: High
**Components**: Database layer

**Description**:
Attacker injects malicious SQL to access or modify data.

**Mitigations**:
1. Use parameterized queries (always)
2. ORM with prepared statements
3. Input validation
4. Least privilege database user

**Implementation**:
```go
// NEVER do this
query := fmt.Sprintf("SELECT * FROM users WHERE address = '%s'", address)

// DO this
query := "SELECT * FROM users WHERE address = $1"
row := db.QueryRow(query, address)
```

**Risk Score**: Likelihood: Low | Impact: Critical | Risk: Medium
**Status**: Mitigated

---

### T11: Key Compromise

**Category**: Information Disclosure, Elevation of Privilege
**Severity**: Critical
**Components**: HSM, Hot wallets

**Description**:
Private keys are exposed, allowing attacker to sign transactions.

**Attack Vectors**:
1. Phishing/social engineering
2. Server compromise
3. Insider threat
4. Supply chain attack

**Mitigations**:
1. HSM for cold storage
2. Multi-sig for critical operations
3. Key rotation procedures
4. Audit logging
5. Principle of least privilege

**Implementation**: See KEY_MANAGEMENT.md

**Risk Score**: Likelihood: Low | Impact: Critical | Risk: High
**Status**: Mitigated with compensating controls

---

### T12: DDoS Attack

**Category**: Denial of Service
**Severity**: High
**Components**: API, Frontend

**Description**:
Attacker overwhelms infrastructure with traffic.

**Mitigations**:
1. CDN with DDoS protection (Cloudflare)
2. Rate limiting
3. Auto-scaling
4. Geographic distribution
5. WAF rules

**Implementation**:
```yaml
# Kubernetes HPA
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: nexus-api
  minReplicas: 3
  maxReplicas: 100
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

**Risk Score**: Likelihood: High | Impact: High | Risk: High
**Status**: Mitigated

---

## Governance Threats

### T13: Governance Takeover

**Category**: Elevation of Privilege
**Severity**: Critical
**Components**: NexusGovernor, NexusTimelock

**Description**:
Attacker gains control of governance to pass malicious proposals.

**Attack Vectors**:
1. Token accumulation (whale attack)
2. Flash loan voting (mitigated by snapshots)
3. Social engineering DAO members
4. Bribing validators

**Mitigations**:
1. High quorum requirements
2. Long timelock delays
3. Emergency multisig veto
4. Guardian role for emergency pause
5. Voting power caps (optional)

**Implementation**:
```solidity
// Emergency guardian can cancel malicious proposals
function cancel(uint256 proposalId) external {
    require(
        msg.sender == guardian ||
        state(proposalId) == ProposalState.Pending,
        "Cannot cancel"
    );
    proposals[proposalId].canceled = true;
}

// High quorum for critical operations
function quorum(uint256 blockNumber) public view override returns (uint256) {
    return (token.getPastTotalSupply(blockNumber) * quorumPercentage) / 100;
}
```

**Risk Score**: Likelihood: Low | Impact: Critical | Risk: High
**Status**: Mitigated with multiple layers

---

## Risk Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RISK MATRIX                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Impact      │                                                              │
│              │                                                              │
│  Critical    │      T11       │   T1, T2, T3   │      T13                  │
│              │                │                │                            │
│  High        │   T4, T7, T10  │    T9, T12     │                            │
│              │                │                │                            │
│  Medium      │      T5        │    T6, T8      │                            │
│              │                │                │                            │
│  Low         │                │                │                            │
│              │                │                │                            │
│              └────────────────┴────────────────┴────────────────────────    │
│                    Low            Medium           High                      │
│                                 Likelihood                                   │
│                                                                              │
│  Legend:                                                                    │
│  - Red zone (Critical/High + Medium/High likelihood): Immediate action      │
│  - Yellow zone: Monitor and improve                                         │
│  - Green zone: Acceptable risk with current controls                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Security Controls Summary

| Threat | Primary Control | Secondary Control | Monitoring |
|--------|-----------------|-------------------|------------|
| T1 Reentrancy | ReentrancyGuard | CEI pattern | Tenderly alerts |
| T2 Oracle | Multi-oracle | TWAP | Price deviation |
| T3 Flash loan | Snapshot voting | Timelock | Unusual voting |
| T4 Access | RBAC | Tests | Role changes |
| T5 Overflow | Solidity 0.8+ | Fuzz tests | N/A |
| T6 MEV | Commit-reveal | Flashbots | Sandwich detection |
| T7 Replay | Chain ID + nonce | Deadline | Duplicate sigs |
| T8 DoS | Batch limits | Pull pattern | Gas usage |
| T9 Auth bypass | RS256 JWT | MFA | Failed logins |
| T10 SQLi | Prepared queries | ORM | Query analysis |
| T11 Key theft | HSM | Multi-sig | Access logs |
| T12 DDoS | CDN/WAF | Auto-scale | Traffic spikes |
| T13 Gov attack | Quorum + timelock | Guardian | Large votes |

---

## Incident Response Integration

For each threat category, see INCIDENT_RESPONSE.md for:
- Detection procedures
- Response playbooks
- Recovery steps
- Post-incident review

---

## Review Schedule

| Review Type | Frequency | Responsible |
|-------------|-----------|-------------|
| Threat model update | Quarterly | Security Team |
| Penetration testing | Semi-annual | External firm |
| Code audit | Before major releases | External auditor |
| Access control review | Quarterly | Security + Compliance |
| Incident tabletop | Quarterly | IRT team |

---

## References

- [STRIDE Threat Model](https://docs.microsoft.com/en-us/azure/security/develop/threat-modeling-tool-threats)
- [OWASP Smart Contract Top 10](https://owasp.org/www-project-smart-contract-top-10/)
- [SWC Registry](https://swcregistry.io/)
- [Consensys Smart Contract Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Trail of Bits Building Secure Contracts](https://github.com/crytic/building-secure-contracts)
