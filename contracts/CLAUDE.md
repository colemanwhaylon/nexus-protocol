# Contracts - Claude Code Instructions

> **Purpose**: This document defines Solidity conventions, security patterns, and smart contract development rules. Claude MUST read and apply these rules before writing any contract code.

---

## Tech Stack

- **Language**: Solidity 0.8.24+
- **Framework**: Foundry (forge, cast, anvil)
- **Libraries**: OpenZeppelin Contracts v5
- **Standards**: ERC-20, ERC-721A, ERC-1400, ERC-2771
- **Testing**: Forge test, fuzz tests, invariant tests
- **Security**: Slither, Echidna, Certora

---

## Contract Architecture

```
contracts/
├── src/
│   ├── core/                     # Core token contracts
│   │   ├── NexusToken.sol        # ERC-20 governance token
│   │   ├── NexusNFT.sol          # ERC-721A NFT collection
│   │   └── NexusSecurityToken.sol # ERC-1400 security token
│   ├── defi/                     # DeFi functionality
│   │   ├── NexusStaking.sol      # Staking with rewards
│   │   ├── RewardsDistributor.sol # Merkle-based rewards
│   │   └── NexusVesting.sol      # Token vesting
│   ├── governance/               # DAO governance
│   │   ├── NexusGovernor.sol     # OpenZeppelin Governor
│   │   ├── NexusTimelock.sol     # Timelock controller
│   │   └── NexusMultiSig.sol     # Multi-signature wallet
│   ├── security/                 # Access control & compliance
│   │   ├── NexusAccessControl.sol # Role-based access
│   │   ├── NexusKYCRegistry.sol  # KYC whitelist/blacklist
│   │   └── NexusEmergency.sol    # Circuit breakers
│   ├── metatx/                   # Meta-transaction support
│   │   └── NexusForwarder.sol    # ERC-2771 forwarder
│   ├── oracles/                  # Price feeds
│   │   └── NexusPriceOracle.sol  # Chainlink integration
│   └── interfaces/               # Contract interfaces
│       ├── INexusToken.sol
│       ├── INexusStaking.sol
│       └── INexusKYCRegistry.sol
├── test/
│   ├── unit/                     # Unit tests
│   ├── fuzz/                     # Fuzz tests
│   ├── invariant/                # Invariant tests
│   └── integration/              # Fork tests
├── script/                       # Deployment scripts
│   ├── Deploy.s.sol
│   └── Upgrade.s.sol
└── echidna/                      # Echidna configs
```

---

## SOLID Principles in Solidity

### S - Single Responsibility

Each contract has ONE purpose:

```
WRONG:
┌─────────────────────────────────────────────────────────────┐
│ contract NexusProtocol {                                    │
│   // Token logic                                            │
│   // Staking logic                                          │
│   // Governance logic                                       │
│   // KYC logic                                              │
│   // Emergency logic                                        │
│   // ALL IN ONE CONTRACT                                    │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

RIGHT:
┌─────────────────────────────────────────────────────────────┐
│ contract NexusToken { /* Token only */ }                    │
│ contract NexusStaking { /* Staking only */ }                │
│ contract NexusGovernor { /* Governance only */ }            │
│ contract NexusKYCRegistry { /* KYC only */ }                │
│ contract NexusEmergency { /* Emergency only */ }            │
└─────────────────────────────────────────────────────────────┘
```

### O - Open/Closed Principle

Use inheritance and composition:

```solidity
// Base contract with virtual functions
abstract contract NexusBase {
    function _beforeAction(address user) internal virtual;
}

// Extend without modifying base
contract NexusStakingWithKYC is NexusBase {
    IKYCRegistry public kycRegistry;

    function _beforeAction(address user) internal virtual override {
        require(kycRegistry.isWhitelisted(user), "Not whitelisted");
    }
}
```

### D - Dependency Inversion

Depend on interfaces, not implementations:

```solidity
// WRONG: Concrete dependency
contract NexusStaking {
    NexusToken public token;  // Concrete type

    constructor() {
        token = new NexusToken();  // Creates dependency
    }
}

// RIGHT: Interface dependency
contract NexusStaking {
    IERC20 public token;  // Interface type

    constructor(IERC20 _token) {  // Injected dependency
        token = _token;
    }
}
```

---

## Security Patterns

### 1. Checks-Effects-Interactions (CEI)

Always follow CEI pattern to prevent reentrancy:

```solidity
function withdraw(uint256 amount) external {
    // CHECKS
    require(balances[msg.sender] >= amount, "Insufficient balance");

    // EFFECTS
    balances[msg.sender] -= amount;

    // INTERACTIONS
    (bool success, ) = msg.sender.call{value: amount}("");
    require(success, "Transfer failed");
}
```

### 2. Reentrancy Guard

Use ReentrancyGuard for external calls:

```solidity
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract NexusStaking is ReentrancyGuard {
    function stake(uint256 amount) external nonReentrant {
        // Safe from reentrancy
    }
}
```

### 3. Access Control

Use role-based access control:

```solidity
import "@openzeppelin/contracts/access/AccessControl.sol";

contract NexusKYCRegistry is AccessControl {
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");

    function addToWhitelist(address account) external onlyRole(COMPLIANCE_ROLE) {
        // Only compliance officers can whitelist
    }
}
```

### 4. Pausable

Emergency pause functionality:

```solidity
import "@openzeppelin/contracts/utils/Pausable.sol";

contract NexusStaking is Pausable {
    function stake(uint256 amount) external whenNotPaused {
        // Cannot stake when paused
    }

    function emergencyPause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }
}
```

---

## Naming Conventions

### Contracts

| Type | Pattern | Example |
|------|---------|---------|
| Main contract | `Nexus{Name}` | `NexusStaking` |
| Interface | `I{ContractName}` | `INexusStaking` |
| Abstract | `{Name}Base` | `StakingBase` |
| Library | `{Name}Lib` | `MathLib` |

### Functions

| Visibility | Pattern | Example |
|------------|---------|---------|
| External | `verbNoun` | `stakeTokens` |
| Public | `verbNoun` | `getBalance` |
| Internal | `_verbNoun` | `_calculateReward` |
| Private | `_verbNoun` | `_updateState` |
| View | `get{Thing}` | `getStakedBalance` |
| Modifier | `verbNoun` | `whenNotPaused` |

### Variables

| Type | Pattern | Example |
|------|---------|---------|
| State variable | `camelCase` | `totalStaked` |
| Constant | `SCREAMING_SNAKE` | `MAX_SUPPLY` |
| Immutable | `i_{name}` | `i_startTime` |
| Mapping | `{key}To{Value}` | `addressToBalance` |
| Function param | `_{name}` | `_amount` |
| Local variable | `camelCase` | `currentBalance` |

### Events

```solidity
// Format: Past tense verb + subject
event Staked(address indexed user, uint256 amount);
event Unstaked(address indexed user, uint256 amount);
event RewardClaimed(address indexed user, uint256 reward);
event WhitelistUpdated(address indexed account, bool status);
```

### Errors

```solidity
// Format: ContractName__ErrorDescription
error NexusStaking__InsufficientBalance();
error NexusStaking__InvalidAmount();
error NexusStaking__NotWhitelisted();
error NexusKYC__AlreadyWhitelisted();
```

---

## Code Organization

### Contract Structure

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title NexusStaking
 * @author Nexus Protocol
 * @notice Stake NEXUS tokens to earn rewards
 * @dev Implements CEI pattern, uses OpenZeppelin ReentrancyGuard
 */
contract NexusStaking is ReentrancyGuard {
    // ============ ERRORS ============
    error NexusStaking__InsufficientBalance();
    error NexusStaking__InvalidAmount();
    error NexusStaking__ZeroAddress();

    // ============ EVENTS ============
    event Staked(address indexed user, uint256 amount);
    event Unstaked(address indexed user, uint256 amount);

    // ============ STATE VARIABLES ============

    // Immutables
    IERC20 public immutable i_nexusToken;

    // Constants
    uint256 public constant MIN_STAKE_AMOUNT = 1 ether;
    uint256 public constant LOCK_PERIOD = 7 days;

    // Storage
    uint256 public totalStaked;
    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakingTimestamp;

    // ============ CONSTRUCTOR ============

    constructor(address _nexusToken) {
        if (_nexusToken == address(0)) revert NexusStaking__ZeroAddress();
        i_nexusToken = IERC20(_nexusToken);
    }

    // ============ EXTERNAL FUNCTIONS ============

    function stake(uint256 _amount) external nonReentrant {
        if (_amount < MIN_STAKE_AMOUNT) revert NexusStaking__InvalidAmount();

        stakedBalance[msg.sender] += _amount;
        totalStaked += _amount;
        stakingTimestamp[msg.sender] = block.timestamp;

        i_nexusToken.transferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount);
    }

    // ============ VIEW FUNCTIONS ============

    function getStakedBalance(address _user) external view returns (uint256) {
        return stakedBalance[_user];
    }

    // ============ INTERNAL FUNCTIONS ============

    function _calculateReward(address _user) internal view returns (uint256) {
        // Reward calculation logic
    }
}
```

---

## Testing Requirements

### Unit Tests

Test each function independently:

```solidity
// test/unit/NexusStaking.t.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../../src/defi/NexusStaking.sol";

contract NexusStakingTest is Test {
    NexusStaking public staking;
    MockToken public token;
    address public user = makeAddr("user");

    function setUp() public {
        token = new MockToken();
        staking = new NexusStaking(address(token));
        token.mint(user, 1000 ether);
    }

    function test_stake_success() public {
        vm.startPrank(user);
        token.approve(address(staking), 100 ether);

        staking.stake(100 ether);

        assertEq(staking.stakedBalance(user), 100 ether);
        assertEq(staking.totalStaked(), 100 ether);
        vm.stopPrank();
    }

    function test_stake_revert_insufficientAmount() public {
        vm.startPrank(user);
        token.approve(address(staking), 0.5 ether);

        vm.expectRevert(NexusStaking.NexusStaking__InvalidAmount.selector);
        staking.stake(0.5 ether);
        vm.stopPrank();
    }
}
```

### Fuzz Tests

Test with random inputs:

```solidity
// test/fuzz/NexusStaking.fuzz.t.sol
contract NexusStakingFuzzTest is Test {
    function testFuzz_stake_anyValidAmount(uint256 _amount) public {
        // Bound to valid range
        _amount = bound(_amount, 1 ether, 1_000_000 ether);

        vm.startPrank(user);
        token.mint(user, _amount);
        token.approve(address(staking), _amount);

        staking.stake(_amount);

        assertEq(staking.stakedBalance(user), _amount);
        vm.stopPrank();
    }
}
```

### Invariant Tests

Test system invariants:

```solidity
// test/invariant/NexusStaking.invariant.t.sol
contract NexusStakingInvariantTest is Test {
    function invariant_totalStakedMatchesBalances() public {
        uint256 totalFromBalances = 0;
        for (uint i = 0; i < stakers.length; i++) {
            totalFromBalances += staking.stakedBalance(stakers[i]);
        }
        assertEq(staking.totalStaked(), totalFromBalances);
    }

    function invariant_contractHoldsStakedTokens() public {
        assertGe(
            token.balanceOf(address(staking)),
            staking.totalStaked()
        );
    }
}
```

---

## Gas Optimization

### 1. Use Custom Errors

```solidity
// WRONG: String errors (expensive)
require(amount > 0, "Amount must be greater than 0");

// RIGHT: Custom errors (cheap)
error InvalidAmount();
if (amount == 0) revert InvalidAmount();
```

### 2. Pack Storage Variables

```solidity
// WRONG: Uses 3 storage slots
contract Inefficient {
    uint256 amount;    // Slot 0
    address user;      // Slot 1
    uint256 timestamp; // Slot 2
}

// RIGHT: Uses 2 storage slots
contract Efficient {
    uint256 amount;    // Slot 0
    address user;      // Slot 1 (20 bytes)
    uint96 timestamp;  // Slot 1 (12 bytes, packed with user)
}
```

### 3. Use Unchecked for Safe Math

```solidity
// When overflow is impossible
function increment(uint256 i) internal pure returns (uint256) {
    unchecked {
        return i + 1;  // Saves gas when overflow can't happen
    }
}
```

### 4. Cache Storage Variables

```solidity
// WRONG: Multiple storage reads
function calculate() external view returns (uint256) {
    return totalStaked * rewardRate / PRECISION;  // 2 storage reads
}

// RIGHT: Cache in memory
function calculate() external view returns (uint256) {
    uint256 _totalStaked = totalStaked;  // 1 storage read
    return _totalStaked * rewardRate / PRECISION;
}
```

---

## ERC-2771 Meta-Transactions

For gasless transactions:

```solidity
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

contract NexusKYCRegistry is ERC2771Context, AccessControl {
    constructor(address _trustedForwarder)
        ERC2771Context(_trustedForwarder)
    {}

    function addToWhitelist(address _account)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        // _msgSender() returns original signer for meta-tx
        // msg.sender would be the forwarder
        whitelist[_account] = true;
        emit WhitelistUpdated(_account, true, _msgSender());
    }

    // Override required by ERC2771Context
    function _msgSender() internal view override returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override returns (bytes calldata) {
        return super._msgData();
    }
}
```

---

## Upgradeability (UUPS)

For upgradeable contracts:

```solidity
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract NexusStakingV1 is UUPSUpgradeable, OwnableUpgradeable {
    // Storage gap for future upgrades
    uint256[50] private __gap;

    function initialize(address _token) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        // Initialize state
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}
}
```

---

## Deployment Scripts

```solidity
// script/Deploy.s.sol
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/core/NexusToken.sol";
import "../src/defi/NexusStaking.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        NexusToken token = new NexusToken();
        NexusStaking staking = new NexusStaking(address(token));

        vm.stopBroadcast();

        console.log("Token deployed:", address(token));
        console.log("Staking deployed:", address(staking));
    }
}
```

---

## Security Checklist

Before deploying ANY contract:

- [ ] CEI pattern followed in all functions
- [ ] ReentrancyGuard on external calls
- [ ] Access control on sensitive functions
- [ ] Pausable for emergency stops
- [ ] Custom errors (not require strings)
- [ ] Events for all state changes
- [ ] No hardcoded addresses (use constructor/immutables)
- [ ] Storage variables packed efficiently
- [ ] Fuzz tests written
- [ ] Invariant tests written
- [ ] Slither clean (no high/medium issues)
- [ ] 100% branch coverage

---

## Forbidden Patterns

**NEVER do these:**

1. `tx.origin` for authentication
2. `block.timestamp` for randomness
3. Floating pragma (always pin version)
4. `selfdestruct` in production
5. Unchecked external calls
6. Magic numbers (use constants)
7. Missing input validation
8. Single-step ownership transfer
9. Hardcoded addresses
10. `transfer()` / `send()` for ETH (use `call`)

---

## When In Doubt

1. **Security**: Follow OpenZeppelin patterns
2. **Gas**: Measure with `forge test --gas-report`
3. **Testing**: Write test first, then implement
4. **Upgrades**: Use UUPS, add storage gaps
5. **Errors**: Use custom errors, not strings
