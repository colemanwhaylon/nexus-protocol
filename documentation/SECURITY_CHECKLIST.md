# Security Checklist - Pre-Deployment

**Version**: 1.0
**Last Updated**: December 29, 2024
**Status**: Active

---

## Overview

This checklist must be completed before any deployment to mainnet. Each item requires sign-off from the designated reviewer. No exceptions.

---

## Phase 1: Code Quality

### Compiler & Build

- [ ] Solidity version pinned (not floating `^0.8.x`)
- [ ] Optimizer enabled with reasonable runs (200-10000)
- [ ] No compiler warnings in production code
- [ ] All contracts compile deterministically
- [ ] Build artifacts reproducible across environments

### Code Standards

- [ ] NatSpec documentation on all public/external functions
- [ ] No TODO/FIXME/HACK comments in production code
- [ ] Consistent naming conventions (camelCase functions, UPPER_CASE constants)
- [ ] No magic numbers (all constants named and documented)
- [ ] No dead code or unused imports

### Access Control

- [ ] All sensitive functions have proper modifiers
- [ ] Role hierarchy documented and tested
- [ ] No functions missing access control
- [ ] Admin functions cannot be called by arbitrary addresses
- [ ] Ownership transfer is two-step (propose + accept)

---

## Phase 2: Static Analysis

### Slither

- [ ] Run: `slither . --exclude-dependencies`
- [ ] All HIGH findings resolved or acknowledged
- [ ] All MEDIUM findings resolved or acknowledged
- [ ] Detector exclusions documented with justification
- [ ] Custom detectors for project-specific patterns

**Required Output**: Slither report with 0 unacknowledged HIGH/MEDIUM

### Aderyn

- [ ] Run: `aderyn .`
- [ ] All findings reviewed
- [ ] Gas optimizations considered

### Solhint

- [ ] Run: `solhint 'contracts/**/*.sol'`
- [ ] No errors (warnings acceptable if documented)

---

## Phase 3: Testing

### Unit Tests

- [ ] All functions have unit tests
- [ ] All revert conditions tested
- [ ] All events tested
- [ ] Edge cases covered (zero, max, boundary)
- [ ] Coverage > 90% line coverage
- [ ] Coverage > 85% branch coverage

### Fuzz Tests (Echidna)

- [ ] Invariant properties defined
- [ ] Run for minimum 1M iterations
- [ ] All invariants hold
- [ ] Corpus saved for regression

**Key Invariants**:
- [ ] Total supply never exceeds max
- [ ] User balance never exceeds total supply
- [ ] Staked + unstaked = user balance
- [ ] Bridge locked = bridge minted (cross-chain)

### Stateful Fuzz Tests (Foundry)

- [ ] `invariant_` tests for core accounting
- [ ] Handler contracts for realistic scenarios
- [ ] Ghost variables for complex invariants

### Integration Tests

- [ ] Multi-contract interactions tested
- [ ] Upgrade paths tested
- [ ] Emergency procedures tested
- [ ] Cross-chain scenarios tested

---

## Phase 4: Formal Verification

### Certora (if applicable)

- [ ] Key properties specified as rules
- [ ] All rules verified (green)
- [ ] Edge cases covered by specifications

**Required Properties**:
- [ ] No unauthorized minting
- [ ] No loss of funds
- [ ] Voting power integrity
- [ ] Timelock enforced

---

## Phase 5: External Review

### Audit

- [ ] Audit firm selected (Tier 1 preferred)
- [ ] Audit scope defined
- [ ] All critical/high findings fixed
- [ ] Audit report published
- [ ] Fix review completed

### Bug Bounty

- [ ] Bug bounty program designed
- [ ] Scope documented
- [ ] Rewards structure defined
- [ ] Platform selected (Immunefi, HackerOne)
- [ ] Ready to launch post-deployment

---

## Phase 6: Operational Security

### Key Management

- [ ] Deployer key is cold wallet or hardware
- [ ] Admin keys are multisig (3-of-5 minimum)
- [ ] Guardian key is separate from admin
- [ ] Private keys never in code or config
- [ ] Key rotation procedure documented

### Access Control Setup

- [ ] Initial roles assigned correctly
- [ ] Role assignment transaction verified
- [ ] Admin cannot be single EOA in production
- [ ] Timelock is admin of upgradeable contracts

### Monitoring

- [ ] Event monitoring configured
- [ ] Alerts for critical events:
  - [ ] Large transfers
  - [ ] Admin actions
  - [ ] Pause events
  - [ ] Upgrade events
- [ ] On-chain monitoring (Forta/OZ Defender)
- [ ] Off-chain monitoring (custom)

---

## Phase 7: Deployment

### Pre-Deployment

- [ ] Deployment script reviewed
- [ ] Gas estimates calculated
- [ ] Deployment order documented
- [ ] Constructor arguments verified
- [ ] Initial state verified

### Testnet Deployment

- [ ] Deployed to testnet (Sepolia/Goerli)
- [ ] All functions tested on testnet
- [ ] Upgrade tested on testnet
- [ ] Emergency pause tested on testnet
- [ ] Waited 7+ days on testnet

### Mainnet Deployment

- [ ] Low gas price period selected
- [ ] Multiple RPC endpoints configured
- [ ] Deployment transaction simulated
- [ ] Etherscan verification prepared
- [ ] Post-deployment verification script ready

---

## Phase 8: Post-Deployment

### Verification

- [ ] All contracts verified on Etherscan
- [ ] Source code matches deployment
- [ ] ABI published
- [ ] Contract addresses documented
- [ ] Initial state verified on-chain

### Documentation

- [ ] Deployment addresses published
- [ ] User documentation updated
- [ ] Developer documentation updated
- [ ] API documentation updated

### Monitoring Activation

- [ ] Monitoring systems activated
- [ ] Alert thresholds configured
- [ ] Incident response team notified
- [ ] 24/7 coverage for first week

---

## Sign-Off Matrix

| Phase | Reviewer | Date | Signature |
|-------|----------|------|-----------|
| Code Quality | Engineering Lead | | |
| Static Analysis | Security Lead | | |
| Testing | QA Lead | | |
| Formal Verification | Security Lead | | |
| External Review | Security Lead | | |
| Operational Security | DevOps Lead | | |
| Deployment | Engineering Lead | | |
| Post-Deployment | Project Owner | | |

---

## Emergency Contacts

| Role | Name | Contact | Backup |
|------|------|---------|--------|
| Security Lead | | | |
| Engineering Lead | | | |
| DevOps Lead | | | |
| Project Owner | | | |

---

## Appendix: Common Vulnerabilities Checklist

### Reentrancy
- [ ] No external calls before state changes
- [ ] ReentrancyGuard on all public functions
- [ ] Cross-function reentrancy considered

### Integer Issues
- [ ] Using Solidity 0.8+ (built-in overflow protection)
- [ ] Explicit unchecked blocks documented
- [ ] Division before multiplication avoided

### Access Control
- [ ] No missing access control
- [ ] No overly permissive access
- [ ] Privilege escalation impossible

### Oracle Manipulation
- [ ] TWAP or multiple sources
- [ ] Staleness checks
- [ ] Circuit breakers

### Flash Loan Attacks
- [ ] No single-block price manipulation
- [ ] Governance uses snapshot voting
- [ ] Staking has minimum lock

### Front-Running
- [ ] Commit-reveal where needed
- [ ] Slippage protection on swaps
- [ ] Deadline parameters

### Denial of Service
- [ ] No unbounded loops
- [ ] No external call loops
- [ ] Pull over push pattern

---

*Completion of this checklist is mandatory before mainnet deployment.*