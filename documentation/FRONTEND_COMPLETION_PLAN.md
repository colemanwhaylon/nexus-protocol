# Frontend Completion Plan (90% → 100%)

> **Created:** January 1, 2026
> **Session Context:** Planning discussion for replacing mock data with real contract integrations

## Overview

The frontend is 90% complete. This document outlines the remaining 10% of work needed to achieve full functionality.

---

## Priority 1: CRITICAL - Fake Handlers (10 items)

### The Problem

When users click buttons on admin pages, they do this:

```
User clicks "Approve KYC" button
    ↓
Code runs: console.log("Approve KYC", id)
    ↓
Nothing actually happens on the blockchain
    ↓
User thinks it worked (no feedback)
```

### The Fix

```
User clicks "Approve KYC" button
    ↓
Code calls: nexusKYC.approveAddress(address)
    ↓
Wallet popup asks user to confirm
    ↓
Transaction sent to blockchain
    ↓
Wait for confirmation
    ↓
Notification Center shows: "✅ KYC Approved for 0x1234..."
```

### File-by-File Breakdown

#### File 1: `app/admin/compliance/page.tsx`

**3 fake handlers to fix:**

| Handler | What it does now | What it should do |
|---------|------------------|-------------------|
| `handleView(id)` | `console.log()` | Open a modal showing full KYC details |
| `handleApprove(id)` | `console.log()` | Call `nexusKYC.addToWhitelist(address)` |
| `handleReject(id)` | `console.log()` | Call `nexusKYC.removeFromWhitelist(address)` |

**Contract:** `NexusKYCRegistry` at `addresses.nexusKYC`

**Functions needed:**
- `addToWhitelist(address)` - Approve someone
- `removeFromWhitelist(address)` - Reject someone
- `isWhitelisted(address)` - Check status

**Mock data to remove (Lines 12-49):**
```javascript
const kycRequests = [
  { id: '1', address: '0x7099...', status: 'pending', ... },
  // ... more fake data
];
```

#### File 2: `app/admin/emergency/page.tsx`

**4 fake handlers to fix:**

| Handler | What it does now | What it should do |
|---------|------------------|-------------------|
| `handlePause()` | `setTimeout` + `setIsPaused(true)` | Call `nexusEmergency.pause()` |
| `handleUnpause()` | `setTimeout` + `setIsPaused(false)` | Call `nexusEmergency.unpause()` |
| `handleTriggerEmergency()` | `setTimeout` + local state | Call `nexusEmergency.triggerEmergency()` |
| `handleResolveEmergency()` | `setTimeout` + local state | Call `nexusEmergency.resolveEmergency()` |

**Contract:** `NexusEmergency` at `addresses.nexusEmergency`

**Functions needed:**
- `pause()` / `unpause()` - Pause protocol
- `triggerEmergency()` / `resolveEmergency()` - Circuit breaker
- `paused()` - Read current pause state
- `emergencyMode()` - Read emergency state

**Mock data to remove (Lines 15-17):**
```javascript
const [isPaused, setIsPaused] = useState(false);
const [isEmergencyMode, setIsEmergencyMode] = useState(false);
```

#### File 3: `app/admin/roles/page.tsx`

**2 fake handlers to fix:**

| Handler | What it does now | What it should do |
|---------|------------------|-------------------|
| `handleGrantRole(role, address)` | `setTimeout` + `console.log()` | Call `accessControl.grantRole(roleHash, address)` |
| `handleRevokeRole(role, address)` | `setTimeout` + `console.log()` | Call `accessControl.revokeRole(roleHash, address)` |

**Contract:** `NexusAccessControl` at `addresses.nexusAccessControl`

**Functions needed:**
- `grantRole(bytes32 role, address account)`
- `revokeRole(bytes32 role, address account)`
- `hasRole(bytes32 role, address account)`
- `getRoleMemberCount(bytes32 role)`
- `getRoleMember(bytes32 role, uint256 index)`

#### File 4: `app/nft/[tokenId]/page.tsx`

**1 fake handler to fix:**

| Handler | What it does now | What it should do |
|---------|------------------|-------------------|
| `handleTransfer()` | `console.log()` | Open modal → Call `nexusNFT.transferFrom(from, to, tokenId)` |

**Contract:** `NexusNFT` at `addresses.nexusNFT`

---

## Priority 2: CRITICAL - Mock Governance Data (3 pages)

### The Problem

```
WHAT USER SEES:              WHAT'S ACTUALLY ON CHAIN:
┌──────────────────────┐     ┌──────────────────────┐
│ Proposal #1: Upgrade │     │                      │
│ Proposal #2: Treasury│     │   (nothing yet)      │
│ Proposal #3: Fee     │     │                      │
└──────────────────────┘     └──────────────────────┘
```

### File 1: `app/governance/page.tsx`

**Mock data to remove:**
- Lines 16-57: Fake proposals array (5 proposals)
- Lines 67-72: Fake voting power and delegation data

**Replace with:**
1. `governor.proposalCount()` or track `ProposalCreated` events
2. For each proposal: `governor.proposals(id)`, `governor.state(id)`, `governor.proposalVotes(id)`
3. User's voting power: `token.getVotes(userAddress)`
4. Delegation status: `token.delegates(userAddress)`

### File 2: `app/governance/create/page.tsx`

**Mock data to remove:**
- Lines 23-25: Fake thresholds

**Replace with:**
1. `governor.proposalThreshold()` → Minimum tokens needed
2. `token.getVotes(userAddress)` → User's voting power
3. On submit: `governor.propose(targets, values, calldatas, description)`

### File 3: `app/governance/[proposalId]/page.tsx`

**Mock data to remove:**
- Lines 22-61: Entire `getMockProposal()` function
- Lines 70-71: Fake user data

**Replace with:**
1. `governor.proposals(proposalId)`
2. `governor.state(proposalId)`
3. `governor.proposalVotes(proposalId)`
4. `governor.hasVoted(proposalId, userAddress)`

**Fake action handlers to fix:**

| Handler | Real replacement |
|---------|------------------|
| `handleVote(support)` | `governor.castVote(proposalId, support)` |
| `handleQueue()` | `governor.queue(proposalId)` |
| `handleExecute()` | `governor.execute(proposalId)` |
| `handleCancel()` | `governor.cancel(proposalId)` |

---

## Priority 3: HIGH - setTimeout Replacements (13 handlers)

Every place with fake delays needs real contract calls:

| File | Line | Fake Delay | Real Contract Call |
|------|------|------------|-------------------|
| `admin/emergency/page.tsx` | 51 | 1000ms | `emergency.pause()` |
| `admin/emergency/page.tsx` | 63 | 1000ms | `emergency.unpause()` |
| `admin/emergency/page.tsx` | 75 | 1000ms | `emergency.triggerEmergency()` |
| `admin/emergency/page.tsx` | 88 | 1000ms | `emergency.resolveEmergency()` |
| `admin/roles/page.tsx` | 63 | 1000ms | `accessControl.grantRole()` |
| `admin/roles/page.tsx` | 86 | 1000ms | `accessControl.revokeRole()` |
| `governance/create/page.tsx` | 41 | 2000ms | `governor.propose()` |
| `governance/page.tsx` | 77 | 1000ms | `token.delegate()` |
| `governance/[proposalId]/page.tsx` | 77 | 1000ms | `governor.castVote()` |
| `governance/[proposalId]/page.tsx` | 87 | 1000ms | `governor.queue()` |
| `governance/[proposalId]/page.tsx` | 95 | 1000ms | `governor.execute()` |
| `governance/[proposalId]/page.tsx` | 101 | 1000ms | `governor.cancel()` |

---

## Priority 4: MEDIUM - Missing Hook Functions

### `useGovernance()` - Needs to add:
- `getProposalCount()`
- `getProposal(id)`
- `getProposalState(id)`
- `getProposalVotes(id)`
- `hasVoted(id, address)`
- `queue(id)`
- `execute(id)`
- `cancel(id)`

### `useNFT()` - Needs to add:
- `transfer(to, tokenId)`
- `approve(to, tokenId)`
- `tokenURI(tokenId)`
- `ownerOf(tokenId)`

### `useAdmin()` - Needs to add:
- `getRoleMembers(role)`
- `pause()` / `unpause()`
- `isPaused()`

---

## Priority 5: MEDIUM - Notification Integration

### Pattern for all contract calls:

```
1. USER ACTION
   ↓
2. NOTIFY: "ℹ️ Starting transaction..."
   ↓
3. WALLET POPUP (user confirms)
   ↓
4. NOTIFY: "⏳ Transaction submitted (tx: 0x1234...)"
   ↓
5. WAIT FOR CONFIRMATION
   ↓
6a. SUCCESS → NOTIFY: "✅ Transaction confirmed!"
6b. FAILURE → NOTIFY: "❌ Transaction failed: [reason]"
   ↓
7. ALL NOTIFICATIONS LOGGED TO CENTRAL PANEL
```

### Pages needing notification integration:

| Page | Actions |
|------|---------|
| `staking/page.tsx` | Approve, Stake, Unstake, Delegate |
| `nft/mint/page.tsx` | Mint |
| `nft/[tokenId]/page.tsx` | Transfer |
| `governance/create/page.tsx` | Create proposal |
| `governance/[proposalId]/page.tsx` | Vote, Queue, Execute, Cancel |
| `admin/compliance/page.tsx` | Approve KYC, Reject KYC |
| `admin/emergency/page.tsx` | Pause, Unpause, Trigger, Resolve |
| `admin/roles/page.tsx` | Grant role, Revoke role |

---

## Summary: What Replaces What

```
FAKE                          →  REAL
─────────────────────────────────────────────────────
console.log("action")         →  contract.function()
setTimeout(1000)              →  await tx.wait()
useState(false)               →  useReadContract({ ... })
mockProposals = [...]         →  governor.proposals(id)
mockVotingPower = BigInt(...) →  token.getVotes(address)
mockKYCRequests = [...]       →  kyc.isWhitelisted(address)
hardcoded role list           →  accessControl.getRoleMember()
local isPaused state          →  emergency.paused()
```

---

## Estimated Effort

| Priority | Category | Effort |
|----------|----------|--------|
| CRITICAL | Wire real contract calls (23 handlers) | ~40 hrs |
| CRITICAL | Replace mock governance data (3 pages) | ~20 hrs |
| HIGH | setTimeout → real async (13 handlers) | ~15 hrs |
| MEDIUM | Missing hook functions (3 hooks) | ~10 hrs |
| MEDIUM | Notification enhancements | ~10 hrs |
| MEDIUM | Error handling (7 files) | ~15 hrs |
| LOW | Loading states, token pages, E2E tests | ~55 hrs |

**Total: ~165 hours**

---

## Recommended Implementation Order

1. Enhance notification system (foundation)
2. Update hooks with missing functions
3. Replace mock data in governance pages
4. Wire up admin page handlers
5. Add transfer to NFT detail page
