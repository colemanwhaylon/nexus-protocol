# Bug Bounty Program

**Version**: 1.0
**Status**: Draft - Pre-Launch
**Platform**: [TBD - Immunefi/HackerOne]

---

## Program Overview

Nexus Protocol is committed to working with the security community to find and fix vulnerabilities. This program outlines the scope, rules, and rewards for responsible disclosure.

---

## Rewards

| Severity | Smart Contracts | Backend/API | Infrastructure |
|----------|-----------------|-------------|----------------|
| Critical | $50,000 - $100,000 | $10,000 - $25,000 | $5,000 - $15,000 |
| High | $10,000 - $50,000 | $5,000 - $10,000 | $2,500 - $5,000 |
| Medium | $2,500 - $10,000 | $1,000 - $5,000 | $500 - $2,500 |
| Low | $500 - $2,500 | $250 - $1,000 | $100 - $500 |

**Note**: Rewards are determined based on impact, likelihood, and quality of report.

---

## Scope

### In Scope - Smart Contracts (Primary)

| Contract | Address | Priority |
|----------|---------|----------|
| NexusToken | 0x... | Critical |
| NexusStaking | 0x... | Critical |
| RewardsDistributor | 0x... | Critical |
| NexusBridge | 0x... | Critical |
| NexusGovernor | 0x... | High |
| NexusTimelock | 0x... | High |
| NexusEmergency | 0x... | High |
| NexusAccessControl | 0x... | High |
| NexusNFT | 0x... | Medium |
| NexusVesting | 0x... | Medium |
| NexusAirdrop | 0x... | Medium |

### In Scope - Backend (Secondary)

| Component | URL/Endpoint | Priority |
|-----------|--------------|----------|
| REST API | api.nexusprotocol.io | High |
| WebSocket | ws.nexusprotocol.io | Medium |
| Indexer | N/A | Medium |

### Out of Scope

- Third-party contracts (OpenZeppelin, Chainlink, etc.)
- Frontend/UI issues (unless leading to fund loss)
- Social engineering attacks
- Physical security
- Issues already known or reported
- Testnet deployments
- Gas optimization suggestions
- Best practice recommendations without security impact

---

## Severity Classification

### Critical

Direct loss of funds or permanent freezing of funds with no recovery mechanism.

**Examples**:
- Unauthorized token minting
- Bypassing access control to drain funds
- Reentrancy leading to fund theft
- Bridge manipulation allowing double-spend
- Governance takeover with immediate execution

### High

Significant impact to protocol functionality or conditional fund loss.

**Examples**:
- Griefing attacks that lock user funds temporarily
- Manipulation of reward calculations
- Denial of service to critical functions
- Bypassing timelock for restricted operations
- Oracle manipulation with limited scope

### Medium

Limited impact or requires specific conditions.

**Examples**:
- Minor calculation errors with capped impact
- Temporary denial of service
- Information disclosure (non-sensitive)
- Front-running with limited profit potential
- Issues requiring admin key compromise

### Low

Minimal impact or informational.

**Examples**:
- Gas inefficiencies affecting users
- Missing events
- Code quality issues with no security impact
- Documentation errors

---

## Rules of Engagement

### Do

- Provide detailed reports with reproduction steps
- Test only on testnets or local forks
- Give us reasonable time to respond (72 hours for critical)
- Keep vulnerabilities confidential until fixed
- Follow responsible disclosure practices

### Do Not

- Test on mainnet contracts
- Exploit vulnerabilities beyond proof-of-concept
- Access or modify other users' data
- Perform denial of service attacks
- Social engineer team members
- Publicly disclose before fix is deployed

---

## Report Requirements

### Required Information

```markdown
## Summary
[One-line description of the vulnerability]

## Severity
[Critical/High/Medium/Low]

## Affected Contract(s)
[Contract name and address]

## Description
[Detailed explanation of the vulnerability]

## Attack Scenario
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Impact
[What can an attacker achieve?]

## Proof of Concept
[Code, transaction, or detailed steps to reproduce]

## Recommended Fix
[Your suggestion for fixing the issue]
```

### Proof of Concept Guidelines

- Use Foundry test format when possible
- Include all necessary setup
- Document assumptions
- Test against latest codebase

**Example PoC**:
```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/core/NexusToken.sol";

contract ExploitPoC is Test {
    NexusToken token;
    address attacker = address(0xBAD);

    function setUp() public {
        // Fork mainnet
        vm.createSelectFork(vm.envString("RPC_URL"));
        token = NexusToken(0x...);
    }

    function testExploit() public {
        // Starting state
        uint256 balanceBefore = token.balanceOf(attacker);

        // Attack steps
        vm.startPrank(attacker);
        // ... exploit code ...
        vm.stopPrank();

        // Verify impact
        uint256 balanceAfter = token.balanceOf(attacker);
        assertGt(balanceAfter, balanceBefore, "Exploit failed");
    }
}
```

---

## Response Timeline

| Severity | Initial Response | Fix Target | Disclosure |
|----------|------------------|------------|------------|
| Critical | 24 hours | 7 days | After fix + 14 days |
| High | 48 hours | 14 days | After fix + 30 days |
| Medium | 72 hours | 30 days | After fix + 30 days |
| Low | 7 days | 60 days | After fix + 30 days |

---

## Safe Harbor

We will not pursue legal action against researchers who:

1. Act in good faith
2. Avoid privacy violations
3. Avoid destruction of data
4. Avoid service disruption
5. Report through official channels
6. Give reasonable time to fix

---

## Contact

**Email**: security@nexusprotocol.io
**PGP Key**: [Available on keyserver]
**Platform**: [Immunefi/HackerOne link]

**Response Hours**: 24/7 for Critical, Business hours for others

---

## Previous Findings

| ID | Severity | Description | Status | Reporter |
|----|----------|-------------|--------|----------|
| | | | | |

---

## Program Updates

| Date | Change |
|------|--------|
| 2024-12-29 | Initial draft |
| | |

---

*Thank you for helping keep Nexus Protocol secure.*
