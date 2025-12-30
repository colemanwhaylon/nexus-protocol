# Deployment Runbook

**Version**: 1.0
**Last Updated**: December 29, 2024
**Classification**: Internal Operations

---

## Overview

This runbook provides step-by-step procedures for deploying and upgrading Nexus Protocol smart contracts. Follow these procedures exactly. Do not skip steps.

---

## Prerequisites

### Required Tools
```bash
# Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Verify versions
forge --version  # >= 0.2.0
cast --version
anvil --version
```

### Required Access
- [ ] Deployer wallet (cold storage or hardware)
- [ ] Admin multisig access
- [ ] RPC endpoint (Alchemy/Infura)
- [ ] Etherscan API key
- [ ] Deployment config file

### Environment Setup
```bash
# Required environment variables
export RPC_URL="https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
export ETHERSCAN_API_KEY="YOUR_KEY"
export DEPLOYER_ADDRESS="0x..."  # Do NOT export private key

# Verify connection
cast block-number --rpc-url $RPC_URL
```

---

## Deployment Order

Contracts must be deployed in this exact order due to dependencies:

```
1. NexusAccessControl (no dependencies)
2. NexusKYCRegistry (depends on: AccessControl)
3. NexusToken (depends on: AccessControl)
4. NexusStaking (depends on: Token, AccessControl)
5. RewardsDistributor (depends on: Token, Staking)
6. NexusTimelock (depends on: AccessControl)
7. NexusGovernor (depends on: Token, Timelock)
8. NexusEmergency (depends on: all above)
9. NexusBridge (depends on: Token, AccessControl)
10. NexusNFT (depends on: AccessControl)
11. NexusVesting (depends on: Token)
12. NexusAirdrop (depends on: Token)
```

---

## Phase 1: Pre-Deployment Checks

### T-24 Hours

```bash
# 1. Verify code is frozen
git status  # Should be clean
git log -1  # Verify commit hash

# 2. Run full test suite
forge test --fork-url $RPC_URL -vvv

# 3. Run static analysis
slither . --exclude-dependencies

# 4. Verify gas estimates
forge script script/Deploy.s.sol --fork-url $RPC_URL
# Record gas estimates for each contract
```

### T-1 Hour

```bash
# 1. Check gas prices
cast gas-price --rpc-url $RPC_URL
# Proceed only if < 50 gwei for non-urgent deploys

# 2. Verify deployer balance
cast balance $DEPLOYER_ADDRESS --rpc-url $RPC_URL
# Need at least 2 ETH for full deployment

# 3. Test RPC connectivity
for i in {1..5}; do cast block-number --rpc-url $RPC_URL; done

# 4. Notify team
# Post in #deployments: "Starting mainnet deployment in 1 hour"
```

---

## Phase 2: Testnet Deployment (Sepolia)

Run this first to verify scripts work.

```bash
# Set testnet RPC
export RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY"

# Deploy all contracts
forge script script/Deploy.s.sol:DeployAll \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Record addresses
cat broadcast/Deploy.s.sol/11155111/run-latest.json | jq '.transactions[].contractAddress'
```

### Testnet Verification Checklist

- [ ] All contracts deployed
- [ ] All contracts verified on Etherscan
- [ ] Basic functionality tested
- [ ] Upgrade tested
- [ ] Emergency pause tested
- [ ] Wait 7 days minimum

---

## Phase 3: Mainnet Deployment

### Step 3.1: Deploy Core Infrastructure

```bash
# Deploy AccessControl
forge script script/Deploy.s.sol:DeployAccessControl \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv

# Record address
ACCESS_CONTROL=0x...

# Verify deployment
cast call $ACCESS_CONTROL "hasRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $DEPLOYER_ADDRESS \
  --rpc-url $RPC_URL
# Should return: true
```

### Step 3.2: Deploy Token

```bash
# Deploy NexusToken
forge script script/Deploy.s.sol:DeployToken \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --sig "run(address)" $ACCESS_CONTROL \
  -vvvv

NEXUS_TOKEN=0x...

# Verify
cast call $NEXUS_TOKEN "name()" --rpc-url $RPC_URL
# Should return: "Nexus Protocol"

cast call $NEXUS_TOKEN "totalSupply()" --rpc-url $RPC_URL
# Should return: 1000000000000000000000000000 (1B tokens)
```

### Step 3.3: Deploy DeFi Contracts

```bash
# Deploy Staking
forge script script/Deploy.s.sol:DeployStaking \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --sig "run(address,address)" $NEXUS_TOKEN $ACCESS_CONTROL \
  -vvvv

NEXUS_STAKING=0x...

# Deploy Rewards
forge script script/Deploy.s.sol:DeployRewards \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --sig "run(address,address)" $NEXUS_TOKEN $NEXUS_STAKING \
  -vvvv

REWARDS_DISTRIBUTOR=0x...
```

### Step 3.4: Deploy Governance

```bash
# Deploy Timelock (48 hour delay)
forge script script/Deploy.s.sol:DeployTimelock \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --sig "run(uint256)" 172800 \
  -vvvv

NEXUS_TIMELOCK=0x...

# Deploy Governor
forge script script/Deploy.s.sol:DeployGovernor \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  --sig "run(address,address)" $NEXUS_TOKEN $NEXUS_TIMELOCK \
  -vvvv

NEXUS_GOVERNOR=0x...
```

### Step 3.5: Deploy Security Contracts

```bash
# Deploy Emergency
forge script script/Deploy.s.sol:DeployEmergency \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv

NEXUS_EMERGENCY=0x...

# Deploy Bridge (if applicable)
forge script script/Deploy.s.sol:DeployBridge \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify \
  -vvvv

NEXUS_BRIDGE=0x...
```

---

## Phase 4: Post-Deployment Configuration

### Step 4.1: Role Assignment

```bash
# Grant OPERATOR_ROLE to backend
cast send $ACCESS_CONTROL "grantRole(bytes32,address)" \
  $(cast keccak "OPERATOR_ROLE") \
  $BACKEND_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY

# Grant PAUSER_ROLE to emergency multisig
cast send $ACCESS_CONTROL "grantRole(bytes32,address)" \
  $(cast keccak "PAUSER_ROLE") \
  $EMERGENCY_MULTISIG \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY
```

### Step 4.2: Transfer Admin to Timelock

```bash
# Transfer DEFAULT_ADMIN_ROLE to Timelock
cast send $ACCESS_CONTROL "grantRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $NEXUS_TIMELOCK \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY

# Renounce deployer admin (IRREVERSIBLE)
cast send $ACCESS_CONTROL "renounceRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $DEPLOYER_ADDRESS \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY
```

### Step 4.3: Verify Final State

```bash
# Verify admin is timelock
cast call $ACCESS_CONTROL "hasRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $NEXUS_TIMELOCK \
  --rpc-url $RPC_URL
# Should return: true

# Verify deployer is NOT admin
cast call $ACCESS_CONTROL "hasRole(bytes32,address)" \
  0x0000000000000000000000000000000000000000000000000000000000000000 \
  $DEPLOYER_ADDRESS \
  --rpc-url $RPC_URL
# Should return: false
```

---

## Phase 5: Verification

### Etherscan Verification

```bash
# Verify all contracts
forge verify-contract $NEXUS_TOKEN \
  src/core/NexusToken.sol:NexusToken \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(address)" $ACCESS_CONTROL)
```

### Functional Verification

```bash
# Test basic operations
# 1. Token transfer
cast send $NEXUS_TOKEN "transfer(address,uint256)" \
  $TEST_ADDRESS 1000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $TEST_KEY

# 2. Staking
cast send $NEXUS_TOKEN "approve(address,uint256)" \
  $NEXUS_STAKING 1000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $TEST_KEY

cast send $NEXUS_STAKING "stake(uint256)" 1000000000000000000 \
  --rpc-url $RPC_URL \
  --private-key $TEST_KEY
```

---

## Phase 6: Documentation

### Update Address Registry

Create `deployments/mainnet.json`:
```json
{
  "network": "mainnet",
  "chainId": 1,
  "deployedAt": "2024-12-29T00:00:00Z",
  "commitHash": "abc123...",
  "contracts": {
    "NexusAccessControl": "0x...",
    "NexusToken": "0x...",
    "NexusStaking": "0x...",
    "RewardsDistributor": "0x...",
    "NexusTimelock": "0x...",
    "NexusGovernor": "0x...",
    "NexusEmergency": "0x...",
    "NexusBridge": "0x..."
  }
}
```

### Notify Stakeholders

```
Subject: Nexus Protocol Mainnet Deployment Complete

Deployment completed at [TIMESTAMP]
All contracts verified on Etherscan

Key Addresses:
- Token: 0x...
- Staking: 0x...
- Governor: 0x...

Monitoring active. No issues detected.
```

---

## Upgrade Procedures

### UUPS Upgrade

```bash
# 1. Deploy new implementation
forge script script/Upgrade.s.sol:DeployNewImplementation \
  --rpc-url $RPC_URL \
  --broadcast \
  --verify

NEW_IMPL=0x...

# 2. Create governance proposal
cast calldata "upgradeToAndCall(address,bytes)" $NEW_IMPL 0x

# 3. Submit through Governor
# (requires token holders to vote)

# 4. After timelock delay, execute
cast send $NEXUS_TIMELOCK "execute(...)" \
  --rpc-url $RPC_URL
```

---

## Rollback Procedures

### If Upgrade Fails

1. **Pause immediately**
```bash
cast send $NEXUS_EMERGENCY "pause()" --rpc-url $RPC_URL
```

2. **Assess damage**
```bash
# Check balances
cast call $NEXUS_TOKEN "totalSupply()" --rpc-url $RPC_URL
# Compare with expected
```

3. **Deploy fix or revert**
- If bug in new code: deploy fixed implementation
- If critical: use emergency drain to multisig

---

## Appendix: Contract Addresses Template

| Contract | Mainnet | Sepolia | Goerli |
|----------|---------|---------|--------|
| AccessControl | | | |
| Token | | | |
| Staking | | | |
| Rewards | | | |
| Timelock | | | |
| Governor | | | |
| Emergency | | | |
| Bridge | | | |

---

*This runbook is a living document. Update after each deployment.*
