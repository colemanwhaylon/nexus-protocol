# Nexus Protocol Incident Response Plan

## Overview

This document outlines the procedures for responding to security incidents affecting the Nexus Protocol. It covers detection, response, recovery, and post-incident activities.

---

## Incident Classification

### Severity Levels

| Level | Name | Description | Response Time | Examples |
|-------|------|-------------|---------------|----------|
| P0 | Critical | Active exploit, funds at risk | Immediate | Reentrancy attack, key compromise |
| P1 | High | Vulnerability discovered, not exploited | < 1 hour | Critical bug in production |
| P2 | Medium | Security issue, limited impact | < 4 hours | Access control bypass |
| P3 | Low | Minor security concern | < 24 hours | Information disclosure |
| P4 | Info | Security improvement needed | < 1 week | Best practice violation |

### Incident Types

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           INCIDENT TYPES                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Smart Contract                    Infrastructure                           │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ • Reentrancy       │           │ • Server compromise│                   │
│  │ • Flash loan       │           │ • DDoS attack      │                   │
│  │ • Oracle manip     │           │ • API breach       │                   │
│  │ • Access control   │           │ • DNS hijack       │                   │
│  │ • Logic bug        │           │ • CDN compromise   │                   │
│  └────────────────────┘           └────────────────────┘                   │
│                                                                              │
│  Key Management                   Social Engineering                        │
│  ┌────────────────────┐           ┌────────────────────┐                   │
│  │ • Key compromise   │           │ • Phishing         │                   │
│  │ • Signer loss      │           │ • Social media     │                   │
│  │ • HSM failure      │           │ • Impersonation    │                   │
│  │ • Backup exposure  │           │ • Insider threat   │                   │
│  └────────────────────┘           └────────────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Response Team

### Incident Response Team (IRT)

| Role | Primary | Backup | Contact |
|------|---------|--------|---------|
| Incident Commander | CTO | Security Lead | @cto-oncall |
| Security Lead | Security Eng | Senior Dev | @security-oncall |
| Smart Contract Lead | Lead Solidity Dev | Senior Dev | @contracts-oncall |
| Infrastructure Lead | DevOps Lead | SRE | @infra-oncall |
| Communications Lead | CEO | Marketing Lead | @comms-oncall |
| Legal Advisor | General Counsel | External Counsel | legal@nexus.xyz |

### On-Call Schedule

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ON-CALL ROTATION                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Week    Security Lead    Smart Contract    Infrastructure                  │
│  ────    ─────────────    ──────────────    ──────────────                  │
│  1       Alice            Bob               Charlie                         │
│  2       Bob              Charlie           Alice                           │
│  3       Charlie          Alice             Bob                             │
│  4       Alice            Bob               Charlie                         │
│                                                                              │
│  Coverage: 24/7/365                                                         │
│  Response SLA: 15 minutes for P0, 1 hour for P1                            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Detection

### Monitoring Systems

| System | Purpose | Alert Threshold |
|--------|---------|-----------------|
| Tenderly | Transaction monitoring | Unusual patterns |
| Forta | Bot-based detection | Anomaly score > 0.8 |
| Grafana | Infrastructure metrics | Error rate > 1% |
| PagerDuty | Alert aggregation | All P0/P1 |
| OZ Defender | Contract monitoring | Policy violations |

### Alert Rules

```yaml
# Smart Contract Alerts
- name: large_withdrawal
  description: Large withdrawal from protocol
  condition: withdrawal_amount > 100000 USD
  severity: P1
  notify: [security-oncall, cto]

- name: unusual_transaction_pattern
  description: Abnormal transaction frequency
  condition: tx_count > 100 in 10 minutes from single address
  severity: P2
  notify: [security-oncall]

- name: governance_attack
  description: Suspicious governance activity
  condition: proposal_created AND proposer_balance < threshold
  severity: P1
  notify: [security-oncall, governance-team]

- name: oracle_manipulation
  description: Price deviation detected
  condition: price_change > 10% in 1 block
  severity: P0
  notify: [security-oncall, cto, ceo]

# Infrastructure Alerts
- name: api_error_rate
  description: High API error rate
  condition: error_rate > 5% over 5 minutes
  severity: P2
  notify: [infra-oncall]

- name: rpc_connection_lost
  description: Lost connection to RPC provider
  condition: rpc_health != healthy for 2 minutes
  severity: P1
  notify: [infra-oncall, security-oncall]
```

---

## Response Procedures

### P0 - Critical Incident Response

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     P0 INCIDENT RESPONSE FLOWCHART                           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐                                                    │
│  │  Incident Detected  │                                                    │
│  │  (0 minutes)        │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Page IRT Team      │  ◄─── PagerDuty auto-escalation                   │
│  │  (0-5 minutes)      │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐         ┌─────────────────────┐                   │
│  │  Assess & Triage    │────────►│  NOT P0?            │                   │
│  │  (5-15 minutes)     │         │  Downgrade          │                   │
│  └──────────┬──────────┘         └─────────────────────┘                   │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  PAUSE CONTRACTS    │  ◄─── Emergency MultiSig (2-of-3)                 │
│  │  (15-30 minutes)    │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Investigate Root   │                                                    │
│  │  Cause              │                                                    │
│  │  (30-120 minutes)   │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Develop & Test     │                                                    │
│  │  Fix                │                                                    │
│  │  (2-24 hours)       │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Deploy Fix         │  ◄─── Timelock bypass if needed                   │
│  │  (varies)           │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Unpause & Monitor  │                                                    │
│  │                     │                                                    │
│  └──────────┬──────────┘                                                    │
│             │                                                                │
│             ▼                                                                │
│  ┌─────────────────────┐                                                    │
│  │  Post-Incident      │                                                    │
│  │  Review             │                                                    │
│  └─────────────────────┘                                                    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Emergency Actions

#### 1. Pause All Contracts

```bash
# Using cast (Foundry)
cast send $EMERGENCY_CONTRACT "pause()" \
  --private-key $EMERGENCY_KEY \
  --rpc-url $RPC_URL

# Verify pause state
cast call $NEXUS_TOKEN "paused()"
```

#### 2. Disable Hot Wallet

```bash
# Rotate hot wallet credentials
aws secretsmanager update-secret \
  --secret-id nexus/hot-wallet \
  --secret-string '{"disabled": true}'

# Verify API key revocation
curl -X POST https://api.nexus.xyz/v1/admin/revoke-key
```

#### 3. Enable Maintenance Mode

```bash
# Enable maintenance mode on frontend
kubectl set env deployment/nexus-frontend MAINTENANCE_MODE=true

# Update CDN rules
aws cloudfront create-invalidation \
  --distribution-id $CF_DIST_ID \
  --paths "/*"
```

---

## Communication Templates

### Internal Alert (Slack)

```
🚨 *P0 INCIDENT DECLARED* 🚨

*Type:* [Smart Contract / Infrastructure / Key Compromise]
*Status:* Active
*Impact:* [Description of impact]
*Incident Commander:* @[name]

*Current Actions:*
• Contracts paused at block [X]
• Investigation in progress
• [Additional actions]

*War Room:* #incident-[date]-[id]
*Zoom:* [link]

*DO NOT* share externally until communications team approves.
```

### User Communication (Twitter/Discord)

```
⚠️ Nexus Protocol Status Update

We are aware of an issue affecting [specific feature].

Current status:
• Protocol is temporarily paused for safety
• User funds are secure
• Our team is actively investigating

We will provide updates every [30 minutes / 1 hour].

For questions: discord.gg/nexus-support
```

### Post-Incident Report (Public)

```markdown
# Nexus Protocol Incident Report

**Date:** [Date]
**Duration:** [Start time] to [End time] UTC
**Severity:** [P0/P1/P2]
**Impact:** [Description]

## Summary

[Brief description of what happened]

## Timeline

- **HH:MM UTC** - [Event]
- **HH:MM UTC** - [Event]
- **HH:MM UTC** - [Resolution]

## Root Cause

[Technical explanation]

## Impact

- Users affected: [Number]
- Funds impacted: [Amount, if any]
- Services affected: [List]

## Resolution

[How the issue was fixed]

## Prevention

[Steps taken to prevent recurrence]

## Lessons Learned

[Key takeaways]
```

---

## Recovery Procedures

### Contract Recovery

```solidity
// Emergency withdrawal function (if needed)
function emergencyWithdraw(
    address token,
    address recipient,
    uint256 amount
) external onlyRole(EMERGENCY_ROLE) whenPaused {
    require(emergencyMultiSig.hasApproval(msg.data), "Requires MultiSig");
    IERC20(token).safeTransfer(recipient, amount);
    emit EmergencyWithdrawal(token, recipient, amount);
}

// Recovery from compromised state
function recoverFromCompromise(
    address[] calldata affectedUsers,
    uint256[] calldata amounts
) external onlyRole(ADMIN_ROLE) whenPaused {
    require(timelockController.hasApproval(msg.data), "Requires Timelock");

    for (uint256 i = 0; i < affectedUsers.length; i++) {
        _compensate(affectedUsers[i], amounts[i]);
    }

    emit CompromiseRecovery(affectedUsers.length);
}
```

### Data Recovery

```bash
# Restore from last known good state
pg_restore -d nexus_production backup_20241229.dump

# Verify data integrity
./scripts/verify_data_integrity.py --compare-chain

# Rebuild indices
./scripts/rebuild_indices.py --full
```

### Key Recovery

```bash
# If emergency key is compromised
# 1. Use cold storage to rotate emergency MultiSig
# 2. Generate new keys in HSM
# 3. Update contract references

# Reconstruct from Shamir shares (requires 3 of 5)
ssss-combine -t 3 -n 5 < shares.txt > recovered_seed.txt

# Verify address matches
cast wallet address --private-key $(cat recovered_seed.txt)
```

---

## Post-Incident Activities

### Retrospective Meeting

**Attendees:** All IRT members + relevant stakeholders

**Agenda:**
1. Timeline reconstruction (30 min)
2. Root cause analysis (30 min)
3. What went well (15 min)
4. What could be improved (30 min)
5. Action items (15 min)

### Documentation Requirements

- [ ] Incident timeline document
- [ ] Root cause analysis
- [ ] Impact assessment
- [ ] Remediation steps taken
- [ ] Prevention measures implemented
- [ ] Lessons learned
- [ ] Updated runbooks (if applicable)
- [ ] Public post-mortem (for significant incidents)

### Follow-up Actions

| Action | Owner | Deadline |
|--------|-------|----------|
| Update monitoring rules | Security Lead | +3 days |
| Add regression tests | Smart Contract Lead | +5 days |
| Review access controls | Security Lead | +7 days |
| Update documentation | Technical Writer | +14 days |
| External audit (if needed) | CTO | +30 days |

---

## Escalation Matrix

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ESCALATION MATRIX                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Time Since Incident    P0 Escalation           P1 Escalation               │
│  ──────────────────    ─────────────           ─────────────               │
│  0-15 min              On-call team            On-call team                 │
│  15-30 min             + CTO, Security Lead    + Team Lead                  │
│  30-60 min             + CEO                   + CTO                        │
│  1-2 hours             + Board notification    + Security Lead              │
│  2-4 hours             + Legal, PR             + CEO (if needed)            │
│  4+ hours              + External support      + External support           │
│                                                                              │
│  External Resources:                                                        │
│  • Trail of Bits: security@trailofbits.com (retainer)                      │
│  • Chainalysis: incident@chainalysis.com (forensics)                       │
│  • Insurance: claims@blockchain-insurance.com                              │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Training & Drills

### Quarterly Tabletop Exercises

**Scenarios to practice:**
1. Smart contract exploit (reentrancy)
2. Oracle manipulation attack
3. Key compromise (hot wallet)
4. DDoS on infrastructure
5. Social engineering attempt

### Annual Red Team Exercise

- External team attempts to exploit protocol
- Full incident response activation
- Measure detection and response times
- Identify gaps in procedures

### Training Requirements

| Role | Training | Frequency |
|------|----------|-----------|
| All IRT | Incident response basics | Annual |
| Security Team | Advanced threat hunting | Quarterly |
| On-call | Runbook walkthroughs | Monthly |
| Executives | Crisis communication | Semi-annual |

---

## Contacts & Resources

### Internal

| Resource | Contact |
|----------|---------|
| Security Team Slack | #security |
| Incident War Room | #incident-active |
| On-call Schedule | PagerDuty |
| Runbooks | Confluence/Notion |

### External

| Resource | Contact | Purpose |
|----------|---------|---------|
| Trail of Bits | security@trailofbits.com | Audit support |
| Chainalysis | incident@chainalysis.com | Fund tracing |
| Legal Counsel | legal@nexus.xyz | Legal guidance |
| PR Agency | pr@agency.com | Media handling |
| Insurance | claims@insurer.com | Loss recovery |

### Tools

| Tool | Purpose | Access |
|------|---------|--------|
| Tenderly | Transaction debugging | tenderly.co |
| Etherscan | Block explorer | etherscan.io |
| Flashbots | MEV protection | flashbots.net |
| OpenZeppelin Defender | Monitoring | defender.openzeppelin.com |
