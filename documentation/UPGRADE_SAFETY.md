# Upgrade Safety Guide

**Version**: 1.0
**Last Updated**: December 29, 2024
**Classification**: Critical Operations

---

## Overview

This document defines safety procedures for upgrading Nexus Protocol smart contracts. Improper upgrades can result in permanent loss of funds or bricked contracts.

---

## UUPS Proxy Pattern

Nexus Protocol uses the UUPS (Universal Upgradeable Proxy Standard) pattern:

```
┌─────────────────────┐
│   ERC1967 Proxy     │  ← Users interact here
│  (stores state)     │
└──────────┬──────────┘
           │ delegatecall
           ▼
┌─────────────────────┐
│   Implementation    │  ← Logic lives here
│  (stateless code)   │
└─────────────────────┘
```

### Key Principles

1. **Proxy holds all state** - Never rely on implementation storage
2. **Implementation is stateless** - No constructor initialization
3. **Upgrade logic in implementation** - `_authorizeUpgrade()` function
4. **Storage layout must be preserved** - Never reorder or remove variables

---

## Storage Layout Safety

### Rule 1: Never Reorder Variables

```solidity
// V1 - Original
contract NexusTokenV1 {
    uint256 public totalSupply;      // slot 0
    mapping(address => uint256) balances;  // slot 1
}

// V2 - WRONG (reordered)
contract NexusTokenV2 {
    mapping(address => uint256) balances;  // slot 0 - COLLISION!
    uint256 public totalSupply;      // slot 1 - COLLISION!
}

// V2 - CORRECT (append only)
contract NexusTokenV2 {
    uint256 public totalSupply;      // slot 0 - same
    mapping(address => uint256) balances;  // slot 1 - same
    uint256 public newVariable;      // slot 2 - new
}
```

### Rule 2: Never Remove Variables

```solidity
// V1
contract StakingV1 {
    uint256 public minStake;
    uint256 public maxStake;
    uint256 public totalStaked;
}

// V2 - WRONG (removed minStake)
contract StakingV2 {
    uint256 public maxStake;    // Now in slot 0 - COLLISION!
    uint256 public totalStaked; // Now in slot 1 - COLLISION!
}

// V2 - CORRECT (deprecate, don't remove)
contract StakingV2 {
    uint256 private __deprecated_minStake;  // Keep slot
    uint256 public maxStake;
    uint256 public totalStaked;
}
```

### Rule 3: Use Storage Gaps

```solidity
contract NexusBaseUpgradeable {
    uint256 public value1;
    uint256 public value2;

    // Reserve 50 slots for future variables
    uint256[50] private __gap;
}

contract NexusChildUpgradeable is NexusBaseUpgradeable {
    uint256 public childValue;

    // Child also reserves slots
    uint256[49] private __gap;  // 49 because we added 1 variable
}
```

### Rule 4: Document Storage Layout

```solidity
/**
 * @title NexusToken Storage Layout
 *
 * Slot | Variable           | Type
 * -----|--------------------|---------
 * 0    | _balances          | mapping
 * 1    | _allowances        | mapping
 * 2    | _totalSupply       | uint256
 * 3    | _name              | string
 * 4    | _symbol            | string
 * 5-54 | __gap              | uint256[50]
 */
```

---

## Initializer Safety

### Disable Initializers in Constructor

```solidity
// CORRECT
contract NexusTokenUpgradeable is UUPSUpgradeable {
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin) public initializer {
        __UUPSUpgradeable_init();
        // ... initialization
    }
}
```

### Use Reinitializer for Upgrades

```solidity
contract NexusTokenV2 is NexusTokenV1 {
    uint256 public newFeature;

    function initializeV2(uint256 _newFeature) public reinitializer(2) {
        newFeature = _newFeature;
    }
}
```

---

## Upgrade Authorization

### Access Control

```solidity
function _authorizeUpgrade(address newImplementation)
    internal
    override
    onlyRole(UPGRADER_ROLE)
{
    // Additional checks
    require(
        newImplementation != address(0),
        "Invalid implementation"
    );

    // Emit event for monitoring
    emit UpgradeAuthorized(msg.sender, newImplementation);
}
```

### Timelock Requirement

```
Upgrade Flow:
1. Developer deploys new implementation
2. Developer creates governance proposal
3. Token holders vote (3 day minimum)
4. Proposal queued in Timelock (48 hour delay)
5. Proposal executed (upgrade performed)

Total time: 5+ days minimum
```

---

## Pre-Upgrade Checklist

### Development Phase

- [ ] Storage layout documented
- [ ] Storage gaps included
- [ ] No variable reordering
- [ ] No variable removal
- [ ] Initializers protected
- [ ] `_disableInitializers()` in constructor
- [ ] `reinitializer(N)` for upgrade init

### Testing Phase

- [ ] Upgrade simulation on fork
- [ ] Storage layout verification
- [ ] State preserved after upgrade
- [ ] New functionality works
- [ ] Old functionality works
- [ ] Access control works
- [ ] Cannot re-initialize

### Pre-Deployment

- [ ] Testnet upgrade successful
- [ ] Wait period completed (7 days)
- [ ] Code audit includes upgrade
- [ ] Governance proposal created
- [ ] Community notified

---

## Upgrade Simulation

### Fork Testing

```solidity
contract UpgradeTest is Test {
    function testUpgrade() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("MAINNET_RPC"));

        // Get current state
        uint256 supplyBefore = token.totalSupply();
        uint256 balanceBefore = token.balanceOf(user);

        // Deploy new implementation
        NexusTokenV2 newImpl = new NexusTokenV2();

        // Simulate upgrade (as timelock)
        vm.prank(timelock);
        UUPSUpgradeable(address(proxy)).upgradeToAndCall(
            address(newImpl),
            abi.encodeCall(newImpl.initializeV2, (newParam))
        );

        // Verify state preserved
        assertEq(token.totalSupply(), supplyBefore);
        assertEq(token.balanceOf(user), balanceBefore);

        // Verify new functionality
        assertEq(NexusTokenV2(address(proxy)).newFeature(), newParam);
    }
}
```

### Storage Layout Verification

```bash
# Generate storage layout
forge inspect NexusTokenV1 storage-layout > layout_v1.json
forge inspect NexusTokenV2 storage-layout > layout_v2.json

# Compare (should only have additions)
diff layout_v1.json layout_v2.json
```

---

## Emergency Upgrade Procedures

### If Critical Bug Discovered

1. **Pause all contracts**
```bash
cast send $EMERGENCY "pauseAll()" --private-key $GUARDIAN_KEY
```

2. **Deploy fix immediately**
```bash
forge script script/EmergencyFix.s.sol --broadcast
```

3. **Execute emergency upgrade**
```solidity
// Emergency contract has 24-hour fast-track
function emergencyUpgrade(address target, address newImpl)
    external
    onlyGuardian
    whenPaused
{
    require(block.timestamp > lastEmergency + 24 hours);
    UUPSUpgradeable(target).upgradeToAndCall(newImpl, "");
    lastEmergency = block.timestamp;
}
```

4. **Post-mortem**
- Document what happened
- Update security procedures
- Notify affected users

---

## Rollback Procedures

### If Upgrade Breaks Functionality

Upgrades cannot be directly rolled back. Options:

1. **Deploy fixed version** (preferred)
   - Fix the bug
   - Deploy new implementation
   - Upgrade again

2. **Emergency pause + migration**
   - Pause broken contract
   - Deploy new contract
   - Migrate state via governance

3. **Emergency drain** (last resort)
   - Drain funds to multisig
   - Redeploy entire protocol
   - Compensate users

---

## Version Management

### Semantic Versioning

```
Format: MAJOR.MINOR.PATCH

MAJOR: Breaking storage changes (should never happen)
MINOR: New features (requires reinitializer)
PATCH: Bug fixes (no reinitializer needed)
```

### Version Registry

```solidity
contract NexusVersionRegistry {
    struct Version {
        uint256 major;
        uint256 minor;
        uint256 patch;
        address implementation;
        uint256 deployedAt;
        string changelogUri;
    }

    mapping(address => Version[]) public versions;

    function registerUpgrade(
        address proxy,
        address newImpl,
        uint256 major,
        uint256 minor,
        uint256 patch,
        string calldata changelog
    ) external onlyTimelock {
        versions[proxy].push(Version({
            major: major,
            minor: minor,
            patch: patch,
            implementation: newImpl,
            deployedAt: block.timestamp,
            changelogUri: changelog
        }));
    }
}
```

---

## Monitoring Upgrades

### Events to Monitor

```solidity
event Upgraded(address indexed implementation);  // From UUPSUpgradeable
event AdminChanged(address previousAdmin, address newAdmin);
event BeaconUpgraded(address indexed beacon);
```

### Alert Configuration

```yaml
# Forta Bot Config
alerts:
  - name: "Contract Upgraded"
    severity: HIGH
    condition: event.name == "Upgraded"
    notify:
      - security@nexusprotocol.io
      - discord.webhook.url

  - name: "Unexpected Upgrade Source"
    severity: CRITICAL
    condition: |
      event.name == "Upgraded" &&
      tx.from != TIMELOCK_ADDRESS
    notify:
      - emergency@nexusprotocol.io
      - pagerduty
```

---

## Appendix: Upgrade History Template

| Date | Contract | From | To | Reinit | Proposer | Tx Hash |
|------|----------|------|-----|--------|----------|---------|
| | NexusToken | 1.0.0 | 1.1.0 | V2 | | |
| | NexusStaking | 1.0.0 | 1.0.1 | N/A | | |

---

*Upgrades are irreversible. Follow this guide exactly.*
