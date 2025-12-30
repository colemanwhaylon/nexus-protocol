# Monitoring Playbook

**Version**: 1.0
**Last Updated**: December 29, 2024
**Classification**: Operations

---

## Overview

This playbook defines monitoring, alerting, and response procedures for Nexus Protocol in production.

---

## Monitoring Stack

```
┌─────────────────────────────────────────────────────────────┐
│                     Alert Destinations                       │
│  PagerDuty │ Slack │ Email │ Discord │ Telegram             │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────┐
│                    Alert Manager                             │
│              (Prometheus Alertmanager)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────┐
│                    Monitoring Layer                          │
├─────────────────┬─────────────────┬────────────────────────┤
│   On-Chain      │   Off-Chain     │   Infrastructure       │
│   (Forta)       │   (Prometheus)  │   (Datadog/Grafana)    │
└─────────────────┴─────────────────┴────────────────────────┘
                           │
┌──────────────────────────┴──────────────────────────────────┐
│                    Data Sources                              │
├─────────────────┬─────────────────┬────────────────────────┤
│  Smart Contracts│  Backend APIs   │  K8s/Docker            │
│  Event Logs     │  Metrics        │  System Metrics        │
└─────────────────┴─────────────────┴────────────────────────┘
```

---

## On-Chain Monitoring

### Critical Events to Monitor

| Event | Contract | Severity | Alert Channel |
|-------|----------|----------|---------------|
| `Transfer` (large) | NexusToken | High | Slack + PagerDuty |
| `Paused` | All | Critical | PagerDuty |
| `Unpaused` | All | High | Slack |
| `RoleGranted` | AccessControl | High | Slack |
| `RoleRevoked` | AccessControl | High | Slack |
| `Upgraded` | UUPS Proxies | Critical | PagerDuty |
| `Slashed` | Staking | High | Slack |
| `EmergencyDrain` | Emergency | Critical | PagerDuty |
| `ProposalCreated` | Governor | Medium | Slack |
| `ProposalExecuted` | Governor | High | Slack |
| `BridgeLocked` | Bridge | High | Slack |
| `BridgeMinted` | Bridge | High | Slack |

### Forta Bot Configuration

```yaml
# forta.config.yml
bots:
  - id: nexus-large-transfer
    name: "Large Transfer Monitor"
    conditions:
      - event: Transfer(address,address,uint256)
        contract: $NEXUS_TOKEN
        filter: value > 1000000e18  # 1M tokens
    severity: HIGH
    alerts:
      - type: slack
        channel: "#alerts-critical"
      - type: pagerduty
        service: nexus-protocol

  - id: nexus-admin-actions
    name: "Admin Action Monitor"
    conditions:
      - event: RoleGranted(bytes32,address,address)
      - event: RoleRevoked(bytes32,address,address)
      - event: Upgraded(address)
      - event: Paused(address)
    severity: CRITICAL
    alerts:
      - type: pagerduty
        service: nexus-protocol
        escalation: immediate
```

### Anomaly Detection

| Metric | Normal Range | Alert Threshold |
|--------|--------------|-----------------|
| Daily transfers | 1,000-10,000 | >50,000 or <100 |
| Average transfer size | 100-10,000 tokens | >100,000 tokens |
| Unique addresses/day | 500-5,000 | >20,000 |
| Contract calls/hour | 100-1,000 | >5,000 |
| Failed transactions | <1% | >5% |

---

## Off-Chain Monitoring

### Backend API Metrics

```yaml
# prometheus/rules/api.yml
groups:
  - name: api_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High error rate on API"

      - alert: SlowResponses
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 2
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "P95 latency above 2s"

      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes / 1024 / 1024 > 500
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Memory usage above 500MB"
```

### Key Metrics

| Metric | Type | Description |
|--------|------|-------------|
| `http_requests_total` | Counter | Total HTTP requests |
| `http_request_duration_seconds` | Histogram | Request latency |
| `db_query_duration_seconds` | Histogram | Database query time |
| `cache_hits_total` | Counter | Redis cache hits |
| `cache_misses_total` | Counter | Redis cache misses |
| `active_connections` | Gauge | Current connections |
| `blockchain_sync_lag` | Gauge | Blocks behind head |

---

## Infrastructure Monitoring

### Kubernetes Alerts

```yaml
# prometheus/rules/k8s.yml
groups:
  - name: k8s_alerts
    rules:
      - alert: PodNotReady
        expr: kube_pod_status_ready{condition="false"} == 1
        for: 5m
        labels:
          severity: warning

      - alert: PodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: critical

      - alert: HighCPUUsage
        expr: sum(rate(container_cpu_usage_seconds_total[5m])) by (pod) > 0.8
        for: 10m
        labels:
          severity: warning

      - alert: PersistentVolumeFillingUp
        expr: kubelet_volume_stats_available_bytes / kubelet_volume_stats_capacity_bytes < 0.2
        for: 5m
        labels:
          severity: warning
```

### Database Monitoring

| Metric | Warning | Critical |
|--------|---------|----------|
| Connection pool usage | >70% | >90% |
| Query latency (P95) | >100ms | >500ms |
| Replication lag | >1s | >10s |
| Disk usage | >70% | >85% |
| Deadlocks/hour | >1 | >10 |

---

## Alert Routing

### Severity Levels

| Level | Description | Response Time | Channel |
|-------|-------------|---------------|---------|
| P1 - Critical | Funds at risk, total outage | 5 minutes | PagerDuty (wake) |
| P2 - High | Partial outage, degraded | 30 minutes | PagerDuty + Slack |
| P3 - Medium | Minor impact, workaround exists | 4 hours | Slack |
| P4 - Low | Informational, optimization | 24 hours | Email |

### Escalation Matrix

```
P1 Critical:
  0-5min:   On-call engineer
  5-15min:  Engineering lead
  15-30min: CTO + Security lead
  30min+:   Executive team

P2 High:
  0-30min:  On-call engineer
  30-60min: Engineering lead
  1-2hr:    CTO

P3/P4: No automatic escalation
```

---

## Runbooks

### RB-001: Contract Paused Alert

**Trigger**: `Paused` event detected

**Steps**:
1. Verify pause was intentional (check Slack/Discord for announcements)
2. If unexpected:
   - Check recent transactions for suspicious activity
   - Contact guardian key holders
   - Prepare incident response
3. Document in incident tracker
4. Monitor for `Unpaused` event

---

### RB-002: Large Transfer Alert

**Trigger**: Transfer >1M tokens

**Steps**:
1. Check if transfer is from known address (treasury, staking contract)
2. If known: Document and close
3. If unknown:
   - Trace transaction origin
   - Check if address is on watchlist
   - If suspicious: Escalate to security team
4. Add address to monitoring if new whale

---

### RB-003: High Error Rate

**Trigger**: API error rate >5%

**Steps**:
1. Check Grafana dashboard for error patterns
2. Identify affected endpoints
3. Check recent deployments
4. If related to deployment:
   - Rollback if necessary
   - Investigate logs
5. If RPC issue:
   - Switch to backup RPC
   - Contact provider
6. Document resolution

---

### RB-004: Upgrade Detected

**Trigger**: `Upgraded` event

**Steps**:
1. **Immediate**: Verify upgrade was through governance
2. Check:
   - Was there a passed proposal?
   - Did timelock execute?
   - Is new implementation expected?
3. If unexpected:
   - **CRITICAL**: Potential compromise
   - Activate incident response
   - Consider emergency pause
4. If expected:
   - Verify new functionality
   - Update documentation
   - Close alert

---

### RB-005: Oracle Failure

**Trigger**: Stale price or zero price detected

**Steps**:
1. Check Chainlink status page
2. Check Pyth status page
3. If both failing:
   - Circuit breaker should auto-trigger
   - Verify circuit breaker activated
   - Monitor for recovery
4. If one failing:
   - Verify fallback is active
   - Alert events should show fallback usage
5. If neither is source:
   - Check contract state
   - May need manual intervention

---

## Dashboard Configuration

### Main Dashboard Panels

```
┌─────────────────────────────────────────────────────────────┐
│  Protocol Health Score: [98%]     Active Users: [1,234]     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ TVL              │  │ 24h Volume       │                 │
│  │ $45.2M           │  │ $2.1M            │                 │
│  │ ▲ +2.3%          │  │ ▼ -5.1%          │                 │
│  └──────────────────┘  └──────────────────┘                 │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │ Transaction Volume (24h)                            │     │
│  │ [========================================]          │     │
│  │ Transfers: 5,234 | Stakes: 892 | Claims: 445       │     │
│  └────────────────────────────────────────────────────┘     │
│                                                              │
│  ┌──────────────────┐  ┌──────────────────┐                 │
│  │ API Latency (P95)│  │ Error Rate       │                 │
│  │ 45ms             │  │ 0.02%            │                 │
│  │ [Normal]         │  │ [Normal]         │                 │
│  └──────────────────┘  └──────────────────┘                 │
│                                                              │
│  ┌────────────────────────────────────────────────────┐     │
│  │ Recent Alerts (Last 24h)                           │     │
│  │ - [INFO] Large transfer: 500K tokens               │     │
│  │ - [WARN] Elevated gas prices detected              │     │
│  └────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### Security Dashboard Panels

- Admin actions (last 7 days)
- Role changes timeline
- Contract upgrade history
- Pause/unpause events
- Large transfers (>100K tokens)
- Failed transactions by type
- Suspicious address watchlist

---

## On-Call Schedule

### Rotation

| Week | Primary | Secondary |
|------|---------|-----------|
| 1 | Engineer A | Engineer B |
| 2 | Engineer B | Engineer C |
| 3 | Engineer C | Engineer A |

### Handoff Checklist

- [ ] Review open incidents
- [ ] Check alert history (last 7 days)
- [ ] Verify PagerDuty contact info
- [ ] Test alert routing
- [ ] Review any pending deployments

---

## Contact Directory

| Role | Name | Phone | Slack |
|------|------|-------|-------|
| On-call Primary | [Rotation] | PagerDuty | @oncall-primary |
| On-call Secondary | [Rotation] | PagerDuty | @oncall-secondary |
| Security Lead | | | @security |
| Engineering Lead | | | @eng-lead |
| DevOps Lead | | | @devops |

---

## Post-Incident Review

### Template

```markdown
## Incident Report: [INC-XXXX]

**Date**:
**Duration**:
**Severity**: P1/P2/P3/P4
**Status**: Resolved/Ongoing

### Summary
[One paragraph description]

### Timeline
- HH:MM - Alert triggered
- HH:MM - Engineer paged
- HH:MM - Root cause identified
- HH:MM - Fix deployed
- HH:MM - All clear

### Root Cause
[Technical explanation]

### Impact
- Users affected: X
- Duration: X minutes
- Financial impact: $X

### Action Items
- [ ] Implement X to prevent recurrence
- [ ] Update runbook for Y
- [ ] Add monitoring for Z

### Lessons Learned
[What did we learn?]
```

---

*This playbook must be reviewed quarterly and after any P1 incident.*
