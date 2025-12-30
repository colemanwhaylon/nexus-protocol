# Nexus Protocol API Reference

## Overview

The Nexus Protocol API provides RESTful endpoints for interacting with the platform. All endpoints return JSON responses and require authentication unless otherwise noted.

**Base URL**: `https://api.nexusprotocol.xyz/v1`

---

## Authentication

### JWT Authentication

All authenticated endpoints require a Bearer token in the Authorization header.

```bash
Authorization: Bearer <jwt_token>
```

### Obtaining a Token

```bash
POST /auth/login
Content-Type: application/json

{
  "wallet_address": "0x1234...5678",
  "signature": "0xabcd...ef01",
  "message": "Sign in to Nexus Protocol\nNonce: abc123\nTimestamp: 1704067200"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIs...",
  "refresh_token": "eyJhbGciOiJSUzI1NiIs...",
  "expires_in": 3600,
  "token_type": "Bearer"
}
```

### Refreshing a Token

```bash
POST /auth/refresh
Content-Type: application/json

{
  "refresh_token": "eyJhbGciOiJSUzI1NiIs..."
}
```

---

## Rate Limiting

| Tier | Requests/min | Requests/day |
|------|--------------|--------------|
| Anonymous | 10 | 100 |
| Basic (Level 1) | 60 | 1,000 |
| Standard (Level 2) | 300 | 10,000 |
| Premium (Level 3) | 1,000 | 100,000 |

Rate limit headers:
```
X-RateLimit-Limit: 60
X-RateLimit-Remaining: 45
X-RateLimit-Reset: 1704067260
```

---

## Endpoints

### Health

#### Check API Health
```
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "timestamp": "2024-12-29T12:00:00Z",
  "services": {
    "database": "healthy",
    "cache": "healthy",
    "blockchain": "healthy"
  }
}
```

---

### Users

#### Get Current User
```
GET /users/me
Authorization: Bearer <token>
```

**Response:**
```json
{
  "id": "usr_abc123",
  "wallet_address": "0x1234...5678",
  "kyc_level": 2,
  "created_at": "2024-01-15T10:30:00Z",
  "roles": ["user"],
  "profile": {
    "email": "user@example.com",
    "email_verified": true
  }
}
```

#### Update User Profile
```
PATCH /users/me
Authorization: Bearer <token>
Content-Type: application/json

{
  "email": "newemail@example.com"
}
```

---

### Staking

#### Get Staking Info
```
GET /staking/info
```

**Response:**
```json
{
  "total_staked": "1000000000000000000000000",
  "total_stakers": 5432,
  "apy": {
    "base": "8.00",
    "max": "20.00"
  },
  "lock_periods": [
    { "days": 0, "bonus": "0.00" },
    { "days": 30, "bonus": "2.00" },
    { "days": 90, "bonus": "5.00" },
    { "days": 180, "bonus": "8.00" },
    { "days": 365, "bonus": "12.00" }
  ],
  "min_stake": "100000000000000000000",
  "contract_address": "0xStaking..."
}
```

#### Get User Stakes
```
GET /staking/stakes
Authorization: Bearer <token>
```

**Response:**
```json
{
  "stakes": [
    {
      "id": "stake_001",
      "amount": "1000000000000000000000",
      "lock_period_days": 90,
      "start_date": "2024-01-15T10:30:00Z",
      "unlock_date": "2024-04-15T10:30:00Z",
      "rewards_earned": "25000000000000000000",
      "apy": "13.00",
      "status": "active"
    }
  ],
  "total_staked": "1000000000000000000000",
  "total_rewards": "25000000000000000000",
  "claimable_rewards": "25000000000000000000"
}
```

#### Estimate Stake Rewards
```
POST /staking/estimate
Content-Type: application/json

{
  "amount": "1000000000000000000000",
  "lock_period_days": 90
}
```

**Response:**
```json
{
  "estimated_apy": "13.00",
  "estimated_daily_reward": "356164383561643",
  "estimated_monthly_reward": "10684931506849300",
  "estimated_yearly_reward": "130000000000000000000"
}
```

---

### Airdrops

#### List Active Airdrops
```
GET /airdrops
```

**Response:**
```json
{
  "airdrops": [
    {
      "id": "airdrop_001",
      "name": "Genesis Airdrop",
      "description": "Rewards for early community members",
      "token": "NXS",
      "total_amount": "10000000000000000000000000",
      "claimed_amount": "5000000000000000000000000",
      "start_date": "2024-01-01T00:00:00Z",
      "end_date": "2024-03-31T23:59:59Z",
      "status": "active",
      "merkle_root": "0xabc123..."
    }
  ]
}
```

#### Check Eligibility
```
GET /airdrops/{airdrop_id}/eligibility
Authorization: Bearer <token>
```

**Response:**
```json
{
  "eligible": true,
  "amount": "1000000000000000000000",
  "proof": [
    "0x1234...",
    "0x5678...",
    "0x9abc..."
  ],
  "claimed": false,
  "claim_deadline": "2024-03-31T23:59:59Z"
}
```

#### Claim Airdrop (Get Transaction Data)
```
POST /airdrops/{airdrop_id}/claim
Authorization: Bearer <token>
```

**Response:**
```json
{
  "to": "0xAirdropContract...",
  "data": "0x2eb4a7ab000000...",
  "gas_estimate": 150000,
  "amount": "1000000000000000000000"
}
```

---

### Governance

#### List Proposals
```
GET /governance/proposals
```

**Query Parameters:**
- `status`: `pending` | `active` | `succeeded` | `defeated` | `executed`
- `page`: Page number (default: 1)
- `limit`: Items per page (default: 20, max: 100)

**Response:**
```json
{
  "proposals": [
    {
      "id": "1",
      "proposer": "0x1234...5678",
      "title": "Increase Staking Rewards",
      "description": "Proposal to increase base APY from 8% to 10%",
      "status": "active",
      "for_votes": "500000000000000000000000",
      "against_votes": "200000000000000000000000",
      "abstain_votes": "50000000000000000000000",
      "start_block": 18500000,
      "end_block": 18550000,
      "quorum": "400000000000000000000000",
      "created_at": "2024-01-20T10:00:00Z"
    }
  ],
  "pagination": {
    "page": 1,
    "limit": 20,
    "total": 45
  }
}
```

#### Get Proposal Details
```
GET /governance/proposals/{proposal_id}
```

**Response:**
```json
{
  "id": "1",
  "proposer": "0x1234...5678",
  "title": "Increase Staking Rewards",
  "description": "Full proposal description...",
  "status": "active",
  "for_votes": "500000000000000000000000",
  "against_votes": "200000000000000000000000",
  "abstain_votes": "50000000000000000000000",
  "start_block": 18500000,
  "end_block": 18550000,
  "eta": null,
  "actions": [
    {
      "target": "0xStaking...",
      "value": "0",
      "signature": "setBaseAPY(uint256)",
      "data": "0x..."
    }
  ],
  "votes": [
    {
      "voter": "0xabc...",
      "support": 1,
      "weight": "100000000000000000000000",
      "reason": "Good for the protocol"
    }
  ]
}
```

#### Get Voting Power
```
GET /governance/voting-power
Authorization: Bearer <token>
```

**Response:**
```json
{
  "voting_power": "50000000000000000000000",
  "delegated_to": null,
  "delegated_from": [
    {
      "address": "0xabc...",
      "amount": "10000000000000000000000"
    }
  ],
  "nft_boost": "1.2",
  "effective_power": "60000000000000000000000"
}
```

---

### NFTs

#### Get Collection Info
```
GET /nfts/collection
```

**Response:**
```json
{
  "name": "Nexus NFT",
  "symbol": "NXNFT",
  "total_supply": 3500,
  "max_supply": 10000,
  "floor_price": "0.08",
  "mint_price": "0.05",
  "royalty_percentage": "5.00",
  "contract_address": "0xNFT...",
  "mint_status": "public"
}
```

#### Get User NFTs
```
GET /nfts/owned
Authorization: Bearer <token>
```

**Response:**
```json
{
  "nfts": [
    {
      "token_id": "1234",
      "name": "Nexus #1234",
      "rarity": "rare",
      "attributes": [
        { "trait_type": "Background", "value": "Cosmic" },
        { "trait_type": "Character", "value": "Guardian" }
      ],
      "image_url": "ipfs://Qm.../1234.png",
      "staking_boost": "1.2"
    }
  ],
  "total": 2
}
```

#### Get Mint Transaction Data
```
POST /nfts/mint
Authorization: Bearer <token>
Content-Type: application/json

{
  "quantity": 2
}
```

**Response:**
```json
{
  "to": "0xNFT...",
  "value": "100000000000000000",
  "data": "0xa0712d68000000...",
  "gas_estimate": 250000
}
```

---

### Compliance (Restricted)

#### Get KYC Status
```
GET /compliance/kyc/status
Authorization: Bearer <token>
```

**Response:**
```json
{
  "level": 2,
  "status": "approved",
  "jurisdiction": "US",
  "verified_at": "2024-01-10T15:30:00Z",
  "expires_at": "2025-01-10T15:30:00Z",
  "required_actions": []
}
```

#### Initiate KYC Upgrade
```
POST /compliance/kyc/upgrade
Authorization: Bearer <token>
Content-Type: application/json

{
  "target_level": 3
}
```

**Response:**
```json
{
  "session_id": "kyc_session_abc123",
  "redirect_url": "https://verify.jumio.com/...",
  "expires_at": "2024-01-29T12:30:00Z"
}
```

#### Whitelist Check (Admin Only)
```
GET /compliance/whitelist/{address}
Authorization: Bearer <token>
X-Role: COMPLIANCE
```

**Response:**
```json
{
  "address": "0x1234...5678",
  "whitelisted": true,
  "kyc_level": 2,
  "jurisdiction": "US",
  "restrictions": [],
  "added_at": "2024-01-10T15:30:00Z"
}
```

---

### Analytics

#### Get Protocol Stats
```
GET /analytics/stats
```

**Response:**
```json
{
  "tvl": "50000000000000000000000000",
  "tvl_usd": "5000000.00",
  "total_users": 15432,
  "active_stakers": 5432,
  "total_staked": "25000000000000000000000000",
  "total_rewards_distributed": "1000000000000000000000000",
  "nft_holders": 3500,
  "governance_participants": 890,
  "24h_volume": "500000000000000000000000"
}
```

#### Get Historical Data
```
GET /analytics/history
```

**Query Parameters:**
- `metric`: `tvl` | `staked` | `users` | `volume`
- `interval`: `1h` | `1d` | `1w`
- `start`: ISO timestamp
- `end`: ISO timestamp

**Response:**
```json
{
  "metric": "tvl",
  "interval": "1d",
  "data": [
    { "timestamp": "2024-01-28T00:00:00Z", "value": "48000000000000000000000000" },
    { "timestamp": "2024-01-29T00:00:00Z", "value": "50000000000000000000000000" }
  ]
}
```

---

### Admin (Restricted)

#### Pause Contract
```
POST /admin/pause
Authorization: Bearer <token>
X-Role: PAUSER
Content-Type: application/json

{
  "contract": "staking",
  "reason": "Security review"
}
```

#### Get System Status
```
GET /admin/status
Authorization: Bearer <token>
X-Role: ADMIN
```

**Response:**
```json
{
  "contracts": {
    "token": { "address": "0x...", "paused": false },
    "staking": { "address": "0x...", "paused": false },
    "nft": { "address": "0x...", "paused": false },
    "governor": { "address": "0x...", "paused": false }
  },
  "last_block": 18550000,
  "last_indexed_block": 18549990,
  "indexer_lag": 10,
  "api_version": "1.0.0"
}
```

---

## Error Responses

### Error Format

```json
{
  "error": {
    "code": "INVALID_REQUEST",
    "message": "The request body is invalid",
    "details": {
      "field": "amount",
      "reason": "must be a positive integer"
    }
  },
  "request_id": "req_abc123"
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `UNAUTHORIZED` | 401 | Missing or invalid authentication |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `INVALID_REQUEST` | 400 | Malformed request |
| `RATE_LIMITED` | 429 | Too many requests |
| `INTERNAL_ERROR` | 500 | Server error |
| `SERVICE_UNAVAILABLE` | 503 | Service temporarily unavailable |
| `KYC_REQUIRED` | 403 | KYC verification required |
| `INSUFFICIENT_BALANCE` | 400 | Insufficient token balance |
| `ALREADY_CLAIMED` | 400 | Airdrop already claimed |

---

## Webhooks

### Registering a Webhook

```
POST /webhooks
Authorization: Bearer <token>
Content-Type: application/json

{
  "url": "https://yourserver.com/webhook",
  "events": ["stake.created", "stake.unstaked", "airdrop.claimed"],
  "secret": "your_webhook_secret"
}
```

### Webhook Events

| Event | Description |
|-------|-------------|
| `stake.created` | New stake created |
| `stake.unstaked` | Stake withdrawn |
| `stake.slashed` | Stake slashed |
| `rewards.claimed` | Rewards claimed |
| `airdrop.claimed` | Airdrop claimed |
| `nft.minted` | NFT minted |
| `nft.transferred` | NFT transferred |
| `proposal.created` | Governance proposal created |
| `proposal.executed` | Proposal executed |
| `kyc.updated` | KYC status changed |

### Webhook Payload

```json
{
  "id": "evt_abc123",
  "type": "stake.created",
  "timestamp": "2024-01-29T12:00:00Z",
  "data": {
    "stake_id": "stake_001",
    "user": "0x1234...5678",
    "amount": "1000000000000000000000",
    "tx_hash": "0xabc..."
  }
}
```

### Webhook Signature Verification

```
X-Nexus-Signature: sha256=abc123...
```

```python
import hmac
import hashlib

def verify_signature(payload, signature, secret):
    expected = hmac.new(
        secret.encode(),
        payload.encode(),
        hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(f"sha256={expected}", signature)
```

---

## SDKs

### JavaScript/TypeScript

```bash
npm install @nexusprotocol/sdk
```

```typescript
import { NexusClient } from '@nexusprotocol/sdk';

const client = new NexusClient({
  apiKey: 'your_api_key',
  network: 'mainnet'
});

// Get staking info
const stakingInfo = await client.staking.getInfo();

// Check airdrop eligibility
const eligibility = await client.airdrops.checkEligibility('airdrop_001');
```

### Python

```bash
pip install nexus-protocol
```

```python
from nexus_protocol import NexusClient

client = NexusClient(api_key="your_api_key", network="mainnet")

# Get staking info
staking_info = client.staking.get_info()

# Check airdrop eligibility
eligibility = client.airdrops.check_eligibility("airdrop_001")
```

### Go

```bash
go get github.com/nexusprotocol/nexus-go
```

```go
import "github.com/nexusprotocol/nexus-go"

client := nexus.NewClient(nexus.Config{
    APIKey:  "your_api_key",
    Network: "mainnet",
})

// Get staking info
info, err := client.Staking.GetInfo(ctx)

// Check airdrop eligibility
eligibility, err := client.Airdrops.CheckEligibility(ctx, "airdrop_001")
```

---

## Changelog

### v1.0.0 (2024-01-29)
- Initial API release
- Staking endpoints
- Airdrop endpoints
- Governance endpoints
- NFT endpoints
- Compliance endpoints
- Analytics endpoints
