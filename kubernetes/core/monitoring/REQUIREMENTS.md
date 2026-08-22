# Monitoring Requirements

**Status**: DEFERRED - Phase 7 is a placeholder for future implementation

## Overview

This document outlines the requirements for cluster monitoring and observability. Full implementation is deferred per project priorities.

## Planned Stack

### Core Components

1. **Prometheus** - Metrics collection and storage
   - Node metrics via node-exporter
   - Kubernetes metrics via kube-state-metrics
   - Application metrics via ServiceMonitor CRDs

2. **Grafana** - Visualization and dashboards
   - Pre-built Kubernetes dashboards
   - Talos-specific dashboards
   - Custom application dashboards

3. **Alertmanager** - Alert routing and notification
   - Slack/Discord integration
   - PagerDuty integration (optional)
   - Email notifications

### Recommended Installation

**kube-prometheus-stack** (Helm chart)
- Bundles Prometheus, Grafana, Alertmanager
- Includes comprehensive default dashboards
- ServiceMonitor support for custom metrics

## Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| Prometheus | 200m | 512Mi | 50Gi (PVC) |
| Grafana | 100m | 128Mi | 1Gi (PVC) |
| Alertmanager | 50m | 64Mi | 1Gi (PVC) |
| Node Exporter | 50m | 64Mi | - |

**Total**: ~400m CPU, ~768Mi memory, ~52Gi storage

## Metrics to Collect

### Cluster Health
- Node readiness and conditions
- Pod status and restarts
- Container resource usage
- etcd health and latency

### Talos-Specific
- Talos API latency
- Machine configuration status
- Upgrade status
- Disk and network metrics

### Application Metrics
- Request rate and latency
- Error rates
- Custom business metrics

### Storage Metrics
- PVC utilization
- democratic-csi provisioning metrics
- TrueNAS pool usage (if exposed)

## Alerting Requirements

### Critical Alerts (Immediate)
- Node NotReady for >5 minutes
- Pod CrashLoopBackOff
- PVC pending for >10 minutes
- etcd cluster unhealthy

### Warning Alerts (1 hour)
- High CPU/memory usage (>80%)
- Disk space low (<20%)
- Certificate expiring soon

### Info Alerts (Daily digest)
- Pod restarts
- Resource quota warnings
- Unusual traffic patterns

## Access Methods

1. **Port-forward** (development)
   ```bash
   kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
   ```

2. **NodePort** (direct access)
   - Grafana: https://node-ip:30080
   - Prometheus: https://node-ip:30090

3. **Tailscale Ingress** (production recommended)
   - grafana.tailnet.ts.net
   - prometheus.tailnet.ts.net

## Implementation Phases

### Phase 1: Basic Metrics (When Ready)
1. Install kube-prometheus-stack
2. Configure persistent storage
3. Import default dashboards
4. Basic alerting setup

### Phase 2: Custom Dashboards
1. Talos-specific dashboard
2. Application-specific dashboards
3. Custom alerts

### Phase 3: Advanced Features
1. Long-term storage (Thanos/Mimir)
2. Distributed tracing (Jaeger)
3. Log aggregation (Loki)

## Values Template

See `kube-prometheus-stack-values.yaml` for Helm values template.

## Dependencies

- **Storage**: Requires truenas-nfs StorageClass (Phase 4)
- **Networking**: Requires Cilium CNI (Phase 3)
- **GitOps**: Optional ArgoCD management (Phase 5)

## Notes

- Start simple, add complexity as needed
- Focus on actionable alerts
- Keep retention reasonable (30 days default)
- Consider resource impact on small cluster
