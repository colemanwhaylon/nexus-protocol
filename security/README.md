# Nexus Protocol - Security Tools

This directory contains security analysis tools and configurations for the Nexus Protocol smart contracts.

## Tools

### Slither (Static Analysis)

Slither is a static analysis framework for Solidity. It detects vulnerabilities, suggests optimizations, and provides insights into code quality.

**Installation:**
```bash
pip3 install slither-analyzer
```

**Usage:**
```bash
cd security/slither
./run-slither.sh
```

**Output:** Reports are generated in `security/slither/reports/`

### Echidna (Fuzzing)

Echidna is a property-based fuzzer for Ethereum smart contracts. It tests invariants through random transaction sequences.

**Installation:**
```bash
# Using docker
docker pull trailofbits/eth-security-toolbox

# Or native installation
# See: https://github.com/crytic/echidna
```

**Usage:**
```bash
cd contracts
echidna . --contract NexusTokenEchidna --config echidna/echidna.yaml
echidna . --contract NexusStakingEchidna --config echidna/echidna.yaml
```

### Custom Detectors

Located in `slither/detectors/`:

| Detector | Description |
|----------|-------------|
| `nexus-reentrancy` | Detects reentrancy in staking/bridge operations |
| `nexus-bridge` | Detects bridge-specific security issues |
| `nexus-access-control` | Detects missing access controls |

**Running Custom Detectors:**
```bash
slither . --detect nexus-reentrancy,nexus-bridge,nexus-access-control
```

## Security Checklist

### Pre-Deployment

- [ ] Run Slither analysis with no high/medium findings
- [ ] Run Echidna for 50,000+ test sequences
- [ ] Review all external calls for reentrancy
- [ ] Verify access control on privileged functions
- [ ] Check for integer overflow/underflow (Solidity 0.8+ has built-in checks)
- [ ] Verify upgrade patterns (UUPS proxies)
- [ ] Review rate limiting configurations

### Bridge Security

- [ ] Multi-sig relay verification
- [ ] Replay attack protection
- [ ] Daily transfer limits
- [ ] Large transfer delays
- [ ] Emergency pause functionality

### Staking Security

- [ ] Unbonding period enforcement
- [ ] Slashing constraints (max 50%)
- [ ] Delegation accounting
- [ ] Voting power conservation

### Token Security

- [ ] Max supply enforcement
- [ ] Snapshot integrity
- [ ] Flash loan fee calculation
- [ ] Permit deadline handling

## Threat Models

See `threat-models/` for STRIDE analysis of each contract component:

- Core Token Operations
- Staking & Delegation
- Cross-chain Bridge
- Governance & Voting
- Access Control

## Incident Response

See `/documentation/INCIDENT_RESPONSE.md` for:

- Emergency contacts
- Pause procedures
- Recovery steps
- Post-incident review

## CI/CD Integration

Add to your GitHub Actions workflow:

```yaml
security-analysis:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4

    - name: Install Slither
      run: pip3 install slither-analyzer

    - name: Run Slither
      run: |
        cd contracts
        slither . --config-file ../security/slither/slither.config.json --json ../slither-results.json

    - name: Upload Results
      uses: actions/upload-artifact@v4
      with:
        name: slither-results
        path: slither-results.json
```

## Resources

- [Slither Documentation](https://github.com/crytic/slither)
- [Echidna Documentation](https://github.com/crytic/echidna)
- [Trail of Bits Blog](https://blog.trailofbits.com/)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/security)
