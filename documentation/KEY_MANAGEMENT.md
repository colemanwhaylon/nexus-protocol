# Nexus Protocol Key Management

## Overview

This document outlines the key management architecture for the Nexus Protocol, including hot/cold wallet strategies, HSM integration patterns, and multi-signature configurations.

---

## Key Hierarchy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           KEY HIERARCHY                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        ┌─────────────────────┐                              │
│                        │    Root Authority   │                              │
│                        │   (Cold Storage)    │                              │
│                        │   HSM / Hardware    │                              │
│                        └──────────┬──────────┘                              │
│                                   │                                          │
│              ┌────────────────────┼────────────────────┐                    │
│              │                    │                    │                    │
│              ▼                    ▼                    ▼                    │
│    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│    │   Treasury      │  │   Upgrade       │  │   Emergency     │          │
│    │   MultiSig      │  │   MultiSig      │  │   MultiSig      │          │
│    │   (3-of-5)      │  │   (4-of-7)      │  │   (2-of-3)      │          │
│    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘          │
│             │                    │                    │                    │
│             ▼                    ▼                    ▼                    │
│    ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│    │   Timelock      │  │   Timelock      │  │   Immediate     │          │
│    │   (48 hours)    │  │   (7 days)      │  │   Execution     │          │
│    └────────┬────────┘  └────────┬────────┘  └────────┬────────┘          │
│             │                    │                    │                    │
│             └────────────────────┼────────────────────┘                    │
│                                  │                                          │
│                                  ▼                                          │
│                        ┌─────────────────────┐                              │
│                        │   Protocol          │                              │
│                        │   Contracts         │                              │
│                        └─────────────────────┘                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Wallet Categories

### 1. Cold Storage (Treasury Root)

**Purpose**: Long-term storage of treasury assets and root authority keys

**Security Requirements**:
- Air-gapped hardware wallet (Ledger/Trezor)
- Geographic distribution (3+ locations)
- Bank safe deposit boxes
- Shamir Secret Sharing for seed backup

**Access Pattern**:
```
Frequency: Monthly or less
Signers Required: 3-of-5
Approval Process:
1. Written proposal submitted
2. 72-hour review period
3. Video conference authorization
4. Physical presence for signing
5. Multi-location verification
```

**Held Assets**:
- 40% of treasury NXS
- Root authority private keys
- Emergency recovery keys

### 2. Warm Storage (Operational Treasury)

**Purpose**: Medium-term operational funds and routine governance

**Security Requirements**:
- Hardware wallet with MPC (Fireblocks/Forta)
- HSM-backed key storage
- 2FA on all access
- IP whitelisting

**Access Pattern**:
```
Frequency: Weekly
Signers Required: 2-of-3
Daily Limit: $100,000
Approval Process:
1. Request via admin dashboard
2. 24-hour waiting period
3. MultiSig execution
```

**Held Assets**:
- 30% of treasury
- Liquidity reserves
- Grant disbursements

### 3. Hot Wallet (Operations)

**Purpose**: Day-to-day operations, gas payments, automated processes

**Security Requirements**:
- AWS KMS / Azure Key Vault
- Rate limiting
- Transaction monitoring
- Automatic alerts

**Access Pattern**:
```
Frequency: Real-time
Signers Required: 1-of-1 (automated)
Daily Limit: $10,000
Per-Transaction Limit: $1,000
```

**Held Assets**:
- Operational ETH for gas
- Small NXS buffer
- Airdrop distribution funds

---

## Hardware Security Module (HSM) Integration

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        HSM INTEGRATION ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                         Application Layer                          │    │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │    │
│  │  │  Go API      │  │  Rust CLI    │  │  Python      │             │    │
│  │  │  Server      │  │  Tools       │  │  Scripts     │             │    │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘             │    │
│  └─────────┼─────────────────┼─────────────────┼─────────────────────┘    │
│            │                 │                 │                           │
│            └─────────────────┼─────────────────┘                           │
│                              │                                              │
│                              ▼                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                      HSM Abstraction Layer                         │    │
│  │  ┌──────────────────────────────────────────────────────────────┐ │    │
│  │  │  interface Signer {                                           │ │    │
│  │  │      Sign(hash []byte) ([]byte, error)                       │ │    │
│  │  │      GetPublicKey() ([]byte, error)                          │ │    │
│  │  │      GetAddress() (common.Address, error)                    │ │    │
│  │  │  }                                                            │ │    │
│  │  └──────────────────────────────────────────────────────────────┘ │    │
│  └─────────────────────────────┬──────────────────────────────────────┘    │
│                                │                                            │
│        ┌───────────────────────┼───────────────────────┐                   │
│        │                       │                       │                   │
│        ▼                       ▼                       ▼                   │
│  ┌──────────────┐       ┌──────────────┐       ┌──────────────┐          │
│  │  AWS KMS     │       │  Azure Key   │       │  YubiHSM     │          │
│  │  CloudHSM    │       │  Vault       │       │  (On-prem)   │          │
│  └──────────────┘       └──────────────┘       └──────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Implementation

```go
// HSM Signer Interface
type HSMSigner interface {
    // Sign signs the given hash using the HSM-stored private key
    Sign(ctx context.Context, hash []byte) ([]byte, error)

    // GetPublicKey returns the public key
    GetPublicKey(ctx context.Context) (*ecdsa.PublicKey, error)

    // GetAddress derives the Ethereum address
    GetAddress(ctx context.Context) (common.Address, error)
}

// AWS KMS Implementation
type AWSKMSSigner struct {
    client *kms.Client
    keyID  string
}

func (s *AWSKMSSigner) Sign(ctx context.Context, hash []byte) ([]byte, error) {
    input := &kms.SignInput{
        KeyId:            aws.String(s.keyID),
        Message:          hash,
        MessageType:      types.MessageTypeDigest,
        SigningAlgorithm: types.SigningAlgorithmSpecEcdsaSha256,
    }

    result, err := s.client.Sign(ctx, input)
    if err != nil {
        return nil, fmt.Errorf("kms sign failed: %w", err)
    }

    return convertToEthSignature(result.Signature)
}

// Azure Key Vault Implementation
type AzureKeyVaultSigner struct {
    client  *azkeys.Client
    keyName string
}

func (s *AzureKeyVaultSigner) Sign(ctx context.Context, hash []byte) ([]byte, error) {
    params := azkeys.SignParameters{
        Algorithm: to.Ptr(azkeys.SignatureAlgorithmES256K),
        Value:     hash,
    }

    result, err := s.client.Sign(ctx, s.keyName, "", params, nil)
    if err != nil {
        return nil, fmt.Errorf("azure sign failed: %w", err)
    }

    return convertToEthSignature(result.Result)
}
```

---

## Multi-Signature Configuration

### Treasury MultiSig (3-of-5)

**Signers**:
| Role | Signer | Backup |
|------|--------|--------|
| CEO | Hardware Wallet | Shamir shard |
| CTO | Hardware Wallet | Shamir shard |
| CFO | Hardware Wallet | Shamir shard |
| Security Lead | Hardware Wallet | Shamir shard |
| Legal Counsel | Hardware Wallet | Shamir shard |

**Parameters**:
```solidity
uint256 public constant REQUIRED_SIGNATURES = 3;
uint256 public constant DAILY_LIMIT = 100_000e18; // 100k NXS
uint256 public constant EXECUTION_DELAY = 48 hours;
```

### Upgrade MultiSig (4-of-7)

**Signers**:
| Role | Type |
|------|------|
| Core Team (3) | Hardware Wallet |
| Technical Advisory Board (2) | Hardware Wallet |
| Security Auditor | Hardware Wallet |
| Community Representative | Hardware Wallet |

**Parameters**:
```solidity
uint256 public constant REQUIRED_SIGNATURES = 4;
uint256 public constant EXECUTION_DELAY = 7 days;
```

### Emergency MultiSig (2-of-3)

**Signers**:
| Role | Type | Availability |
|------|------|--------------|
| Security Lead | Hardware + Hot | 24/7 |
| On-call Engineer | Hardware + Hot | 24/7 |
| CEO | Hardware | Business hours |

**Parameters**:
```solidity
uint256 public constant REQUIRED_SIGNATURES = 2;
uint256 public constant EXECUTION_DELAY = 0; // Immediate
```

---

## Key Rotation Procedures

### Scheduled Rotation (Quarterly)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     QUARTERLY KEY ROTATION PROCESS                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Day -14: Preparation Phase                                                 │
│  ├── Generate new key pair in HSM                                           │
│  ├── Verify key generation                                                  │
│  └── Document new key metadata                                              │
│                                                                              │
│  Day -7: Testing Phase                                                      │
│  ├── Test signing with new key (testnet)                                    │
│  ├── Verify transaction execution                                           │
│  └── Update development environments                                        │
│                                                                              │
│  Day 0: Rotation Execution                                                  │
│  ├── Submit rotation proposal to MultiSig                                   │
│  ├── Collect required signatures                                            │
│  ├── Execute on-chain rotation                                              │
│  └── Verify new key is active                                               │
│                                                                              │
│  Day +1: Verification                                                       │
│  ├── Test production signing                                                │
│  ├── Monitor for anomalies                                                  │
│  └── Update documentation                                                   │
│                                                                              │
│  Day +7: Cleanup                                                            │
│  ├── Disable old key                                                        │
│  ├── Archive key metadata                                                   │
│  └── Update incident response docs                                          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Emergency Rotation (Compromise Response)

```
IMMEDIATE (0-1 hour):
1. Activate incident response team
2. Pause affected contracts
3. Revoke compromised key access
4. Enable emergency backup key

SHORT-TERM (1-24 hours):
1. Generate replacement keys
2. Test replacement keys
3. Deploy key rotation transactions
4. Re-enable paused contracts

POST-INCIDENT (24-72 hours):
1. Conduct forensic analysis
2. Document incident timeline
3. Update security procedures
4. Communicate with stakeholders
```

---

## MPC (Multi-Party Computation) Setup

### Threshold Signature Scheme

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     MPC THRESHOLD SIGNATURE                                  │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Configuration: 2-of-3 Threshold                                            │
│                                                                              │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                │
│  │   Party A    │     │   Party B    │     │   Party C    │                │
│  │   (Node 1)   │     │   (Node 2)   │     │   (Node 3)   │                │
│  │              │     │              │     │              │                │
│  │  Key Share   │     │  Key Share   │     │  Key Share   │                │
│  │     s_A      │     │     s_B      │     │     s_C      │                │
│  └──────┬───────┘     └──────┬───────┘     └──────┬───────┘                │
│         │                    │                    │                         │
│         └────────────────────┼────────────────────┘                         │
│                              │                                              │
│                              ▼                                              │
│                    ┌─────────────────┐                                      │
│                    │  MPC Protocol   │                                      │
│                    │  ───────────    │                                      │
│                    │  1. Commit      │                                      │
│                    │  2. Exchange    │                                      │
│                    │  3. Combine     │                                      │
│                    │  4. Sign        │                                      │
│                    └────────┬────────┘                                      │
│                             │                                               │
│                             ▼                                               │
│                    ┌─────────────────┐                                      │
│                    │   Signature     │                                      │
│                    │   (r, s, v)     │                                      │
│                    └─────────────────┘                                      │
│                                                                              │
│  Benefits:                                                                  │
│  • No single point of failure                                               │
│  • Key shares never combined                                                │
│  • Fault tolerance (1 node can fail)                                        │
│  • Distributed trust                                                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Provider Options

| Provider | Type | Features | Use Case |
|----------|------|----------|----------|
| Fireblocks | SaaS | MPC, Policy Engine, Staking | Primary custody |
| Forta | Self-hosted | MPC, Open source | Backup/Dev |
| Gnosis Safe | On-chain | MultiSig, Modules | Treasury |
| Lit Protocol | Decentralized | MPC, Programmable | Advanced use |

---

## WalletConnect Integration

### Supported Wallets

| Wallet | Type | MPC | Hardware |
|--------|------|-----|----------|
| MetaMask | Browser | No | Via Lattice |
| Ledger Live | Desktop | No | Yes |
| Rainbow | Mobile | No | No |
| Gnosis Safe | Web | Via Signers | Via Signers |
| Fireblocks | Enterprise | Yes | HSM |

### Integration Code

```typescript
// WalletConnect v2 Integration
import { createWeb3Modal, defaultWagmiConfig } from '@web3modal/wagmi'
import { mainnet, sepolia, arbitrum, polygon } from 'wagmi/chains'

const projectId = process.env.WALLETCONNECT_PROJECT_ID

const metadata = {
  name: 'Nexus Protocol',
  description: 'DeFi + NFT + Enterprise Tokenization',
  url: 'https://nexusprotocol.xyz',
  icons: ['https://nexusprotocol.xyz/logo.png']
}

const chains = [mainnet, sepolia, arbitrum, polygon]

const wagmiConfig = defaultWagmiConfig({
  chains,
  projectId,
  metadata,
})

const modal = createWeb3Modal({
  wagmiConfig,
  projectId,
  chains,
  themeMode: 'dark',
  themeVariables: {
    '--w3m-accent': '#6366f1'
  }
})
```

---

## Security Best Practices

### Key Generation

1. **Use Hardware Random Number Generator**
   ```bash
   # Generate entropy from hardware RNG
   dd if=/dev/hwrng bs=32 count=1 2>/dev/null | xxd -p
   ```

2. **Verify Key Quality**
   ```bash
   # Check entropy quality
   rngtest < /dev/random
   ```

3. **Air-Gapped Generation**
   - Use dedicated offline machine
   - Boot from read-only media
   - No network connectivity
   - Destroy machine after use

### Backup Strategy

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         BACKUP STRATEGY                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Primary Backup: Shamir Secret Sharing (3-of-5)                             │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Shard 1: Bank Safe Deposit (Location A)                           │    │
│  │  Shard 2: Bank Safe Deposit (Location B)                           │    │
│  │  Shard 3: Fireproof Safe (CEO Home)                               │    │
│  │  Shard 4: Fireproof Safe (CTO Home)                               │    │
│  │  Shard 5: Escrow Service                                          │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Secondary Backup: Encrypted Cloud                                          │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  Provider: AWS S3 (Multi-region)                                   │    │
│  │  Encryption: AES-256-GCM                                           │    │
│  │  Key: Hardware-derived (not stored digitally)                      │    │
│  │  Access: MFA + IP Whitelist                                        │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
│  Recovery Testing: Quarterly                                                │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │  1. Reconstruct key from shards                                    │    │
│  │  2. Verify derived address matches                                 │    │
│  │  3. Sign test transaction                                          │    │
│  │  4. Document results                                               │    │
│  │  5. Re-secure shards                                               │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Access Control

| Operation | Required Auth | Time Lock |
|-----------|---------------|-----------|
| View balance | API key | None |
| Sign transaction <$1k | 1-of-1 + 2FA | None |
| Sign transaction <$10k | 2-of-3 + 2FA | 1 hour |
| Sign transaction <$100k | 3-of-5 + video | 24 hours |
| Sign transaction >$100k | 4-of-5 + in-person | 48 hours |
| Rotate key | 4-of-5 + video | 7 days |
| Add signer | 5-of-5 + in-person | 14 days |

---

## Monitoring & Alerts

### Key Usage Monitoring

```yaml
# Prometheus metrics for key operations
- name: nexus_key_signing_total
  help: Total number of signing operations
  type: counter
  labels: [key_id, environment]

- name: nexus_key_signing_latency_ms
  help: Signing operation latency
  type: histogram
  buckets: [10, 50, 100, 500, 1000]

- name: nexus_key_last_rotation_timestamp
  help: Timestamp of last key rotation
  type: gauge
  labels: [key_id]
```

### Alert Rules

```yaml
# PagerDuty alerts
alerts:
  - name: UnauthorizedKeyAccess
    condition: key_access_denied > 3
    window: 5m
    severity: critical

  - name: AbnormalSigningVolume
    condition: signing_rate > 100/hour
    severity: warning

  - name: KeyRotationOverdue
    condition: days_since_rotation > 90
    severity: medium

  - name: HSMConnectionLost
    condition: hsm_health != healthy
    window: 1m
    severity: critical
```

---

## Compliance

### SOC 2 Requirements

- [ ] Access logging for all key operations
- [ ] Quarterly access reviews
- [ ] Background checks for key custodians
- [ ] Segregation of duties
- [ ] Change management procedures

### Audit Trail

All key operations are logged with:
- Timestamp (UTC)
- Operation type
- Key identifier
- Initiator identity
- Approval chain
- Success/failure status
- Transaction hash (if applicable)
