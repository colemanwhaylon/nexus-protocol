# Nexus Protocol Compliance Framework

## Overview

This document outlines the regulatory compliance framework for Nexus Protocol, covering KYC/AML procedures, securities considerations, data privacy, and jurisdictional requirements.

---

## Regulatory Landscape

### Token Classification

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        TOKEN CLASSIFICATION                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  NXS Token (Utility Token)                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  • Primary use: Governance and platform access                      │    │
│  │  • No expectation of profit from others' efforts                    │    │
│  │  • Functional at launch                                             │    │
│  │  • Howey Test: Likely NOT a security                                │    │
│  │  • Jurisdictional analysis required per region                      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  NXNFT (Non-Fungible Token)                                                 │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  • Digital collectible/membership                                   │    │
│  │  • Utility features (access, staking boost)                        │    │
│  │  • Generally not securities                                        │    │
│  │  • Royalty considerations per jurisdiction                         │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  NXS-SEC (Security Token)                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  • Explicitly designed as security                                  │    │
│  │  • ERC-1400 compliant                                               │    │
│  │  • Transfer restrictions enforced                                   │    │
│  │  • Requires exemption or registration                               │    │
│  │  • US: Regulation D (506c) / Regulation S                          │    │
│  │  • EU: Prospectus exemption / MiFID II                             │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Jurisdictional Requirements

| Jurisdiction | Utility Token | Security Token | NFT | KYC Required |
|--------------|---------------|----------------|-----|--------------|
| United States | State-by-state | Reg D/S/A+ | Varies | Yes (SEC) |
| European Union | MiCA compliant | MiFID II | Generally OK | Yes (AMLD) |
| United Kingdom | FCA guidance | FCA authorized | Generally OK | Yes |
| Singapore | MAS guidelines | SFA licensed | Generally OK | Yes |
| Switzerland | FINMA token classes | Licensed | Generally OK | Yes |
| Cayman Islands | Favorable | CIMA regulated | Generally OK | Basic |

---

## KYC/AML Framework

### Identity Verification Levels

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        KYC VERIFICATION LEVELS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Level 0: Anonymous                                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Requirements: None                                                 │    │
│  │  Access: View-only, testnet                                        │    │
│  │  Limits: None                                                       │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Level 1: Basic                                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Requirements: Email, wallet signature                             │    │
│  │  Access: NFT minting, small airdrops                               │    │
│  │  Limits: $1,000/day, $5,000/month                                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Level 2: Standard                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Requirements: Government ID, selfie, address                      │    │
│  │  Access: Full platform (except security tokens)                    │    │
│  │  Limits: $50,000/day, $200,000/month                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Level 3: Enhanced (Accredited)                                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Requirements: Level 2 + accreditation proof + source of funds     │    │
│  │  Access: Security tokens, high-value transactions                  │    │
│  │  Limits: Unlimited                                                  │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### KYC Process Flow

```
User Registration
       │
       ▼
┌──────────────┐
│ Email Verify │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Wallet Sign  │────►│ Level 1      │───► Basic Access
└──────┬───────┘     └──────────────┘
       │
       │ Upgrade Request
       ▼
┌──────────────┐
│ ID Document  │
│ Upload       │
└──────┬───────┘
       │
       ▼
┌──────────────┐     ┌──────────────┐
│ Liveness     │────►│ Provider     │
│ Check        │     │ Verification │
└──────────────┘     └──────┬───────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
              ▼             ▼             ▼
        ┌──────────┐  ┌──────────┐  ┌──────────┐
        │ Approved │  │ Manual   │  │ Rejected │
        │          │  │ Review   │  │          │
        └────┬─────┘  └────┬─────┘  └────┬─────┘
             │             │             │
             ▼             ▼             ▼
        Level 2       Compliance    Denied
        Access        Team Review   Access
```

### KYC Provider Integration

```go
// KYC Provider Interface
type KYCProvider interface {
    VerifyIdentity(ctx context.Context, data IdentityData) (*VerificationResult, error)
    CheckSanctions(ctx context.Context, name string, dob time.Time) (*SanctionResult, error)
    PerformAML(ctx context.Context, address common.Address) (*AMLResult, error)
}

// Supported Providers
type JumioProvider struct { /* ... */ }
type OnfidoProvider struct { /* ... */ }
type ChainanalysisProvider struct { /* ... */ }

// Verification Data
type IdentityData struct {
    FirstName    string
    LastName     string
    DateOfBirth  time.Time
    Nationality  string
    Address      AddressData
    Document     DocumentData
    SelfieImage  []byte
}

// Result
type VerificationResult struct {
    Status       VerificationStatus
    Score        float64
    Checks       []CheckResult
    Warnings     []string
    RejectionReason string
}
```

---

## Sanctions & Watchlist Screening

### Screened Lists

| List | Source | Update Frequency |
|------|--------|------------------|
| OFAC SDN | US Treasury | Daily |
| OFAC Non-SDN | US Treasury | Daily |
| EU Sanctions | European Commission | Daily |
| UN Sanctions | United Nations | Weekly |
| UK Sanctions | FCDO | Daily |
| PEP Lists | Various | Weekly |
| Adverse Media | Various | Continuous |

### On-Chain Screening

```solidity
// NexusKYCRegistry.sol
contract NexusKYCRegistry is AccessControl {
    mapping(address => KYCStatus) public kycStatus;
    mapping(address => bool) public blacklist;

    enum KYCStatus { NONE, PENDING, LEVEL1, LEVEL2, LEVEL3, REJECTED }

    // Called before any transfer
    function canTransfer(address from, address to) external view returns (bool) {
        // Check blacklist
        if (blacklist[from] || blacklist[to]) {
            return false;
        }

        // Check KYC level for restricted operations
        if (isRestrictedOperation()) {
            return kycStatus[from] >= KYCStatus.LEVEL2 &&
                   kycStatus[to] >= KYCStatus.LEVEL2;
        }

        return true;
    }

    // COMPLIANCE_ROLE can update status
    function updateKYCStatus(address user, KYCStatus status)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        kycStatus[user] = status;
        emit KYCStatusUpdated(user, status);
    }

    // Add to blacklist (sanctions, etc.)
    function addToBlacklist(address user, string calldata reason)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        blacklist[user] = true;
        emit AddedToBlacklist(user, reason);
    }
}
```

---

## Transfer Restrictions

### ERC-1400 Security Token Compliance

```solidity
// NexusSecurityToken.sol
contract NexusSecurityToken is IERC1400 {
    // Partition-based holdings
    bytes32 public constant CLASS_A = keccak256("CLASS_A");
    bytes32 public constant CLASS_B = keccak256("CLASS_B");

    // Transfer restriction checks
    function canTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata data
    ) external view returns (bool, bytes1, bytes32) {
        // Check 1: KYC verification
        if (!kycRegistry.isVerified(to)) {
            return (false, 0x50, "Recipient not KYC verified");
        }

        // Check 2: Accreditation for US investors
        if (kycRegistry.getJurisdiction(to) == JURISDICTION_US) {
            if (!accreditationRegistry.isAccredited(to)) {
                return (false, 0x51, "Recipient not accredited");
            }
        }

        // Check 3: Lock-up period
        if (isInLockup(from)) {
            return (false, 0x52, "Tokens in lock-up");
        }

        // Check 4: Investor count limits
        if (wouldExceedInvestorLimit(to)) {
            return (false, 0x53, "Would exceed investor limit");
        }

        // Check 5: Jurisdiction restrictions
        if (isRestrictedJurisdiction(to)) {
            return (false, 0x54, "Restricted jurisdiction");
        }

        return (true, 0x51, "");
    }

    // Forced transfer for compliance (e.g., court order)
    function controllerTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata data,
        bytes calldata operatorData
    ) external onlyRole(CONTROLLER_ROLE) {
        require(isValidComplianceAction(operatorData), "Invalid compliance action");
        _transfer(from, to, amount);
        emit ControllerTransfer(msg.sender, from, to, amount, data, operatorData);
    }
}
```

### Lock-up Periods

| Investor Type | Lock-up Period | Regulation |
|---------------|----------------|------------|
| US Reg D | 12 months | Rule 144 |
| US Reg S (non-US) | 6 months | Reg S |
| Team/Advisors | 12-48 months | Internal |
| Private Sale | 6-18 months | Internal |

---

## Data Privacy (GDPR/CCPA)

### Data Categories

| Category | Examples | Retention | Legal Basis |
|----------|----------|-----------|-------------|
| Identity | Name, DOB, ID | 7 years | Legal obligation |
| Contact | Email, phone | Active + 2 years | Consent |
| Wallet | Address | Indefinite | Contract |
| Transaction | Hashes, amounts | Indefinite | Legal obligation |
| KYC Documents | ID images | 7 years | Legal obligation |

### User Rights Implementation

```go
// GDPR/CCPA Compliance API
type PrivacyAPI struct {
    userService UserService
    kycService  KYCService
}

// Data Subject Access Request
func (api *PrivacyAPI) HandleDSAR(ctx context.Context, userID string) (*DSARResponse, error) {
    user, err := api.userService.GetUser(ctx, userID)
    if err != nil {
        return nil, err
    }

    // Compile all user data
    return &DSARResponse{
        PersonalData: user.GetPersonalData(),
        TransactionHistory: api.getTransactionHistory(ctx, userID),
        KYCData: api.kycService.GetKYCData(ctx, userID),
        ConsentHistory: api.getConsentHistory(ctx, userID),
        ExportDate: time.Now(),
    }, nil
}

// Right to Erasure (with limitations)
func (api *PrivacyAPI) HandleErasureRequest(ctx context.Context, userID string) error {
    // Cannot delete:
    // - Data required for legal compliance (AML records)
    // - Blockchain transaction records (immutable)

    // Can delete:
    // - Marketing preferences
    // - Non-essential personal data
    // - Session/analytics data

    return api.userService.AnonymizeUser(ctx, userID)
}

// Right to Portability
func (api *PrivacyAPI) ExportUserData(ctx context.Context, userID string) ([]byte, error) {
    data, err := api.HandleDSAR(ctx, userID)
    if err != nil {
        return nil, err
    }

    return json.Marshal(data)
}
```

### Privacy by Design

1. **Data Minimization**: Only collect necessary data
2. **Purpose Limitation**: Use data only for stated purposes
3. **Storage Limitation**: Delete when no longer needed
4. **Encryption**: All PII encrypted at rest and in transit
5. **Access Controls**: Role-based access to personal data
6. **Audit Logging**: All data access logged

---

## Audit Trail

### Compliance Events

```solidity
// Events for compliance audit trail
event KYCStatusUpdated(address indexed user, KYCStatus status, uint256 timestamp);
event BlacklistUpdated(address indexed user, bool blacklisted, string reason);
event TransferRestricted(address indexed from, address indexed to, bytes1 reason);
event ControllerTransfer(address indexed controller, address from, address to, uint256 amount);
event ComplianceDocumentAdded(bytes32 indexed docHash, string docType);
event JurisdictionUpdated(address indexed user, bytes2 jurisdiction);
```

### Off-Chain Audit Log

```go
type AuditLog struct {
    ID          string    `json:"id"`
    Timestamp   time.Time `json:"timestamp"`
    Actor       string    `json:"actor"`       // Who performed action
    Action      string    `json:"action"`      // What was done
    Subject     string    `json:"subject"`     // Who was affected
    Details     string    `json:"details"`     // Additional context
    IPAddress   string    `json:"ip_address"`
    UserAgent   string    `json:"user_agent"`
    TxHash      string    `json:"tx_hash,omitempty"`
    BlockNumber uint64    `json:"block_number,omitempty"`
}

// Audit log retention: 7 years minimum
// Storage: Immutable append-only log
// Access: COMPLIANCE_ROLE and AUDITOR_ROLE only
```

---

## Reporting Requirements

### Suspicious Activity Reports (SARs)

**Triggers**:
- Transactions > $10,000 (CTR threshold)
- Structuring patterns
- Unusual transaction velocity
- Sanctioned address interaction
- Adverse media hits

**Process**:
1. Automated detection
2. Compliance team review
3. Documentation
4. Filing with FinCEN (US) / relevant authority
5. Continued monitoring

### Tax Reporting

| Jurisdiction | Form | Threshold | Deadline |
|--------------|------|-----------|----------|
| US | 1099-MISC | $600 | Jan 31 |
| US | 1099-K | $20,000 + 200 tx | Jan 31 |
| EU | DAC7 | Platform reporting | Jan 31 |
| UK | HMRC | Varies | Annual |

---

## Compliance Controls Matrix

| Control | Implementation | Frequency | Owner |
|---------|----------------|-----------|-------|
| KYC Verification | Jumio/Onfido | On registration | Compliance |
| Sanctions Screening | Chainalysis | Real-time | Compliance |
| Transaction Monitoring | Custom rules | Real-time | Security |
| PEP Screening | World-Check | Weekly | Compliance |
| Adverse Media | Dow Jones | Weekly | Compliance |
| Audit Review | Internal | Quarterly | Internal Audit |
| External Audit | Big 4 | Annual | CFO |
| Regulatory Reporting | Automated | Monthly | Compliance |
| Staff Training | LMS | Annual | HR |

---

## Restricted Jurisdictions

### Prohibited

These jurisdictions are **completely blocked**:
- North Korea
- Iran
- Cuba
- Syria
- Crimea Region
- Donetsk/Luhansk Regions

### Restricted

Additional requirements for:
- United States (accreditation for security tokens)
- China (case-by-case)
- India (utility tokens only)
- Russia (enhanced due diligence)

### Implementation

```solidity
// Jurisdiction checking
mapping(bytes2 => bool) public prohibitedJurisdictions;
mapping(bytes2 => bool) public restrictedJurisdictions;

function checkJurisdiction(address user) internal view returns (bool allowed) {
    bytes2 jurisdiction = kycRegistry.getJurisdiction(user);

    if (prohibitedJurisdictions[jurisdiction]) {
        return false;
    }

    if (restrictedJurisdictions[jurisdiction]) {
        return hasEnhancedDueDiligence(user);
    }

    return true;
}
```

---

## Compliance Contacts

| Role | Name | Email |
|------|------|-------|
| Chief Compliance Officer | TBD | compliance@nexus.xyz |
| MLRO (Money Laundering Reporting Officer) | TBD | mlro@nexus.xyz |
| DPO (Data Protection Officer) | TBD | dpo@nexus.xyz |
| External Legal Counsel | TBD | legal@lawfirm.com |

---

## Regulatory Resources

- [SEC Digital Asset Framework](https://www.sec.gov/corpfin/framework-investment-contract-analysis-digital-assets)
- [FinCEN Guidance](https://www.fincen.gov/resources/statutes-and-regulations/guidance)
- [MiCA Regulation](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX%3A52020PC0593)
- [FATF Virtual Asset Guidance](https://www.fatf-gafi.org/publications/fatfrecommendations/documents/guidance-rba-virtual-assets.html)
- [GDPR Official Text](https://gdpr-info.eu/)
