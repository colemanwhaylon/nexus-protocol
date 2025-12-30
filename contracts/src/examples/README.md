# Nexus Protocol - Educational Security Examples

This directory contains vulnerable and secure contract pairs for educational purposes.

## Purpose

These contracts demonstrate common smart contract vulnerabilities and their fixes:

1. **Learn to identify vulnerabilities** - See real-world attack patterns
2. **Understand secure patterns** - Learn production-ready implementations
3. **Test security tools** - Use with Slither, Echidna, and other tools
4. **Interview preparation** - Common security questions answered in code

## Contract Pairs

### VulnerableVault / SecureVault

Demonstrates:
- **Reentrancy** - External calls before state updates
- **Access Control** - Missing role-based permissions
- **Denial of Service** - Unbounded loops
- **Input Validation** - Missing bounds checking

### VulnerableOracle / SecureOracle

Demonstrates:
- **Flash Loan Attacks** - Spot price manipulation
- **Oracle Manipulation** - Single-source price feeds
- **Staleness Issues** - Using outdated prices
- **Price Bounds** - Missing sanity checks
- **TWAP Implementation** - Time-weighted average prices

## Usage

### For Learning

```solidity
// Read VulnerableVault.sol - identify the 5 vulnerabilities
// Then read SecureVault.sol - see how each is fixed
```

### For Testing Security Tools

```bash
# Run Slither on vulnerable contracts
slither contracts/src/examples/vulnerable/

# Slither should detect:
# - Reentrancy in VulnerableVault.withdraw()
# - Missing access control on setPaused()
# - State variable changes after external call
```

### For Fuzzing with Echidna

```solidity
// Create an Echidna harness that tries to exploit the vulnerabilities
contract VulnerableVaultEchidna is VulnerableVault {
    function echidna_no_reentrancy() public view returns (bool) {
        // Try to break invariants
    }
}
```

## Security Patterns Summary

| Vulnerability | Bad Pattern | Good Pattern |
|--------------|-------------|--------------|
| Reentrancy | External call before state | `nonReentrant` + CEI pattern |
| Access Control | No modifiers | `onlyRole(ADMIN_ROLE)` |
| DoS | Unbounded loops | Pull pattern / pagination |
| Oracle Manipulation | Spot price | TWAP + multi-source |
| Input Validation | No checks | Bounds + sanity checks |
| Front-running | Predictable | Commit-reveal / slippage |

## Common Attack Vectors

### Reentrancy Attack Flow
```
1. Attacker deposits 1 ETH
2. Attacker calls withdraw()
3. Before balance=0, attacker's receive() is called
4. Attacker's receive() calls withdraw() again
5. Balance check passes (still 1 ETH)
6. Attacker drains contract
```

### Flash Loan + Oracle Attack
```
1. Attacker takes flash loan (1M USDC)
2. Attacker swaps into pool, skewing reserves
3. Oracle reads manipulated spot price
4. Attacker exploits lending protocol with bad price
5. Attacker swaps back, repays flash loan
6. Attacker profits
```

## References

- [SWC Registry](https://swcregistry.io/) - Smart Contract Weakness Classification
- [Consensys Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/security)
- [Trail of Bits](https://github.com/crytic/building-secure-contracts)
