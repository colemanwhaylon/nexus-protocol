# Nexus Protocol Tokenomics

## Overview

The Nexus Protocol ecosystem is powered by three primary token types:

1. **NEXUS (NXS)** - Governance and utility ERC-20 token
2. **Nexus NFT (NXNFT)** - Membership and access ERC-721A token
3. **Nexus Security Token (NXS-SEC)** - Compliant ERC-1400 security token

---

## NEXUS Token (NXS)

### Token Specifications

| Parameter | Value |
|-----------|-------|
| Name | Nexus Token |
| Symbol | NXS |
| Standard | ERC-20 |
| Decimals | 18 |
| Max Supply | 1,000,000,000 (1 billion) |
| Initial Supply | 0 (fair launch) |

### Token Distribution

```
┌────────────────────────────────────────────────────────────────────────────┐
│                         NEXUS TOKEN DISTRIBUTION                           │
├────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Community & Ecosystem (40%)     ████████████████████                     │
│   - Staking Rewards: 20%          ██████████                               │
│   - Liquidity Mining: 10%         █████                                    │
│   - Ecosystem Grants: 5%          ██░                                      │
│   - Airdrops: 5%                  ██░                                      │
│                                                                             │
│   Team & Advisors (15%)           ███████░                                 │
│   - Core Team: 12%                ██████                                   │
│   - Advisors: 3%                  █░                                       │
│   (4-year vesting, 1-year cliff)                                           │
│                                                                             │
│   Treasury (20%)                  ██████████                               │
│   - Protocol Development: 10%    █████                                     │
│   - Security Fund: 5%            ██░                                       │
│   - Insurance Fund: 5%           ██░                                       │
│                                                                             │
│   Private Sale (15%)              ███████░                                 │
│   (18-month vesting, 6-month cliff)                                        │
│                                                                             │
│   Public Sale (10%)               █████                                    │
│   (20% at TGE, 80% over 6 months)                                          │
│                                                                             │
└────────────────────────────────────────────────────────────────────────────┘
```

### Vesting Schedules

| Allocation | Cliff | Vesting | TGE Unlock |
|------------|-------|---------|------------|
| Team | 12 months | 48 months | 0% |
| Advisors | 6 months | 24 months | 0% |
| Private Sale | 6 months | 18 months | 0% |
| Public Sale | None | 6 months | 20% |
| Ecosystem | None | 60 months | 10% |
| Treasury | Governance | As needed | 0% |

### Token Utility

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                            TOKEN UTILITY                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │   GOVERNANCE    │  │    STAKING      │  │     ACCESS      │            │
│  │  ────────────   │  │  ────────────   │  │  ────────────   │            │
│  │  • Voting       │  │  • Earn rewards │  │  • Premium      │            │
│  │  • Proposals    │  │  • Delegation   │  │    features     │            │
│  │  • Treasury     │  │  • Slashing     │  │  • NFT minting  │            │
│  │    decisions    │  │    penalties    │  │  • API access   │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │   FEE PAYMENT   │  │   COLLATERAL    │  │   INCENTIVES    │            │
│  │  ────────────   │  │  ────────────   │  │  ────────────   │            │
│  │  • Protocol     │  │  • Bridge       │  │  • Liquidity    │            │
│  │    fees         │  │    collateral   │  │    provision    │            │
│  │  • Gas rebates  │  │  • Validator    │  │  • Bug bounties │            │
│  │                 │  │    bonds        │  │  • Referrals    │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Staking Economics

### Reward Structure

```solidity
// Annual reward calculation
stakingAPR = baseAPR + lockBonus + volumeBonus

// Where:
// baseAPR = 8% (minimum for any staker)
// lockBonus = 0-12% (based on lock duration)
// volumeBonus = 0-5% (based on protocol volume)
```

### Lock Period Bonuses

| Lock Period | APR Bonus | Total APR* |
|-------------|-----------|------------|
| No lock | 0% | 8% |
| 30 days | 2% | 10% |
| 90 days | 5% | 13% |
| 180 days | 8% | 16% |
| 365 days | 12% | 20% |

*Assuming base APR of 8%, without volume bonus

### Slashing Conditions

| Violation | Slashing Rate | Cooldown |
|-----------|---------------|----------|
| Double signing | 5% | 7 days |
| Extended downtime (>24h) | 1% | 1 day |
| Malicious proposal | 10% | 30 days |
| Governance manipulation | 20% | 90 days |

### Delegation

- Delegators earn 90% of staking rewards
- Validators earn 10% commission
- No slashing for delegators (validators absorb)
- Minimum delegation: 100 NXS

---

## Emission Schedule

### Annual Emission

```
Year 1:  200,000,000 NXS (20% of max supply)
Year 2:  150,000,000 NXS (15% of max supply)
Year 3:  100,000,000 NXS (10% of max supply)
Year 4:   75,000,000 NXS (7.5% of max supply)
Year 5+:  50,000,000 NXS/year (5% decreasing to 2%)
```

### Emission Curve

```
Supply
(millions)
    │
1000├────────────────────────────────────────────────── MAX SUPPLY
    │                                          ....─────
 800├                              ......──────
    │                    ....──────
 600├            ...─────
    │      ..────
 400├   ..─
    │ ─
 200├─
    │
    └───────┬───────┬───────┬───────┬───────┬───────┬───► Years
            1       2       3       4       5       10
```

---

## Fee Structure

### Protocol Fees

| Action | Fee | Recipient |
|--------|-----|-----------|
| NFT Mint | 0.01 ETH | Treasury (50%), Stakers (50%) |
| Secondary Sale | 2.5% royalty | Creator (70%), Treasury (30%) |
| Airdrop Claim | 0 NXS | N/A |
| Bridge Transfer | 0.1% | Bridge Operators (80%), Treasury (20%) |
| Governance Proposal | 1000 NXS | Refunded if passed |

### Fee Distribution

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          FEE DISTRIBUTION                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                        Total Protocol Fees                                   │
│                              │                                               │
│             ┌────────────────┼────────────────┐                             │
│             │                │                │                             │
│             ▼                ▼                ▼                             │
│      ┌──────────┐     ┌──────────┐     ┌──────────┐                        │
│      │ Staking  │     │ Treasury │     │   Burn   │                        │
│      │ Rewards  │     │          │     │          │                        │
│      │   50%    │     │   40%    │     │   10%    │                        │
│      └──────────┘     └──────────┘     └──────────┘                        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Nexus NFT (NXNFT)

### Collection Specs

| Parameter | Value |
|-----------|-------|
| Max Supply | 10,000 |
| Mint Price | 0.05 ETH |
| Royalty | 5% (EIP-2981) |
| Max Per Wallet | 3 (public sale) |

### Rarity Tiers

| Tier | Supply | Percentage | Benefits |
|------|--------|------------|----------|
| Legendary | 100 | 1% | All benefits + 50% staking boost |
| Epic | 400 | 4% | Priority access + 30% staking boost |
| Rare | 1,500 | 15% | 20% staking boost + governance multiplier |
| Common | 8,000 | 80% | Base benefits + 10% staking boost |

### NFT Utility

1. **Staking Multipliers**: Boost staking rewards based on rarity
2. **Governance Weight**: Additional voting power
3. **Premium Access**: Early access to new features
4. **Revenue Share**: Portion of protocol fees
5. **Whitelist**: Guaranteed allocation in future drops

---

## Nexus Security Token (NXS-SEC)

### Token Specifications

| Parameter | Value |
|-----------|-------|
| Standard | ERC-1400 |
| Jurisdictions | US (Reg D), EU (exempt), Singapore |
| Minimum Investment | $10,000 |
| Accreditation | Required (US) |

### Partitions

| Partition | Purpose | Transferability |
|-----------|---------|-----------------|
| CLASS_A | Equity-like | Restricted (12-month lock) |
| CLASS_B | Revenue share | Restricted (6-month lock) |
| CLASS_C | Utility | Free (after KYC) |

### Compliance Features

- **Forced Transfers**: Controller can move tokens for compliance
- **Whitelist**: Only KYC'd addresses can hold
- **Document Hash**: Legal documents stored on-chain
- **Transfer Restrictions**: Jurisdiction-based rules

---

## Governance

### Voting Power

```
votingPower = tokenBalance + delegatedVotes + nftBoost

// Where:
// tokenBalance = NXS balance
// delegatedVotes = votes delegated from other holders
// nftBoost = bonus from NFT holdings (0-50%)
```

### Proposal Thresholds

| Action | Threshold | Quorum |
|--------|-----------|--------|
| Standard Proposal | 10,000 NXS | 4% |
| Treasury Spend (<$100k) | 10,000 NXS | 4% |
| Treasury Spend (>$100k) | 100,000 NXS | 10% |
| Parameter Change | 50,000 NXS | 8% |
| Emergency Action | 1,000,000 NXS | 15% |
| Contract Upgrade | 1,000,000 NXS | 20% |

### Voting Period

| Phase | Duration |
|-------|----------|
| Proposal Delay | 1 day |
| Voting Period | 7 days |
| Timelock | 2 days |
| **Total** | **10 days** |

---

## Economic Security

### Attack Cost Analysis

**51% Attack on Governance**:
```
Required tokens = 51% of voting supply
Current price = $0.10 (hypothetical)
Attack cost = 510,000,000 * $0.10 = $51,000,000
Slippage impact = ~$15,000,000
Total attack cost = ~$66,000,000
```

**Economic Defense**:
- Timelock delays allow community response
- MultiSig can veto malicious proposals
- Emergency pause stops execution
- Slashing penalizes attackers

### Token Velocity Management

1. **Staking Incentives**: Lock tokens for higher rewards
2. **NFT Integration**: Require NXS for minting
3. **Fee Burning**: Reduce circulating supply
4. **Long-term Vesting**: Reduce sell pressure

---

## Treasury Management

### Treasury Composition Target

| Asset | Target % | Purpose |
|-------|----------|---------|
| NXS | 40% | Governance, rewards |
| ETH | 30% | Operations, gas |
| Stablecoins | 25% | Stability, expenses |
| Other | 5% | Strategic investments |

### Treasury Spend Categories

| Category | Annual Budget |
|----------|---------------|
| Development | 40% |
| Marketing | 20% |
| Security Audits | 15% |
| Operations | 15% |
| Reserve | 10% |

---

## Token Launch Strategy

### Phase 1: Private Sale
- Allocation: 15% (150M NXS)
- Price: $0.05
- Raise: $7.5M
- Investors: VCs, strategic partners

### Phase 2: Public Sale
- Allocation: 10% (100M NXS)
- Price: $0.08
- Raise: $8M
- Method: Dutch auction

### Phase 3: Liquidity Mining
- Initial liquidity: $2M ETH + $2M NXS
- Emissions: 2M NXS/week (Year 1)
- Pools: NXS/ETH, NXS/USDC

### Phase 4: Ecosystem Growth
- Grants program launch
- Airdrop campaigns
- Partnership integrations

---

## Simulation Results

### 5-Year Projections (Base Case)

| Year | Circulating Supply | Staked % | Price* | Market Cap* |
|------|-------------------|----------|--------|-------------|
| 1 | 300M | 35% | $0.15 | $45M |
| 2 | 500M | 45% | $0.25 | $125M |
| 3 | 650M | 55% | $0.40 | $260M |
| 4 | 750M | 60% | $0.60 | $450M |
| 5 | 850M | 65% | $1.00 | $850M |

*Hypothetical projections for illustration only

### Sensitivity Analysis

| Scenario | 5-Year Price | Key Assumptions |
|----------|--------------|-----------------|
| Bear | $0.20 | Low adoption, high emissions |
| Base | $1.00 | Steady growth, moderate staking |
| Bull | $3.00 | High adoption, high staking |

---

## Risk Factors

1. **Regulatory Risk**: Token classification uncertainty
2. **Market Risk**: Crypto market volatility
3. **Technical Risk**: Smart contract vulnerabilities
4. **Adoption Risk**: Competition, user acquisition
5. **Liquidity Risk**: DEX pool depth

### Mitigations

- Conservative token release schedule
- Multi-jurisdictional legal review
- Comprehensive security audits
- Diversified use cases
- Strategic liquidity partnerships
