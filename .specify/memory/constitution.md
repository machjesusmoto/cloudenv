# cloudenv Constitution

Core principles governing all infrastructure decisions in this cloud environment project.

## Core Principles

### I. Infrastructure as Code (NON-NEGOTIABLE)

All infrastructure MUST be defined declaratively and version-controlled. Manual configuration is prohibited except for initial bootstrap operations.

- Every resource has a corresponding Git-tracked definition
- Changes flow through PR → Review → Merge → Apply
- Drift detection and remediation are automated

### II. Public Repository Security

This repository is public as a living DevOps portfolio. All commits must be audit-ready.

- **No secrets**: API keys, passwords, tokens never committed
- **No identifying IPs**: Use placeholders (`<VPS_PUBLIC_IP>`, `<TAILSCALE_IP>`)
- **No credentials**: SSH keys, certificates handled externally
- Security review required before any commit touching sensitive paths

### III. Immutable Infrastructure

Prefer immutable, API-driven systems over mutable, SSH-administered ones.

- Talos Linux for Kubernetes (no SSH, API-only)
- GitOps via ArgoCD for all workloads
- Configuration changes via declarative updates, not in-place modification
- Rollback capability for every change

### IV. Defense in Depth

Security implemented at multiple layers; no single point of failure.

- Network segmentation (virbr1 private network)
- Tailscale for secure remote access
- Pod Security Standards enforced
- Secrets encrypted at rest

### V. Observable Systems

All systems must expose health, metrics, and logs for operational visibility.

- Prometheus/metrics endpoints on all services
- Structured logging in JSON format
- Health checks and readiness probes required
- Alerting for resource exhaustion and failures

### VI. Resource Efficiency

Optimize for the constrained environment (single VPS host).

- Right-size VM allocations
- Memory ballooning enabled
- Avoid over-provisioning
- Monitor and reclaim unused resources

## Technical Standards

### Kubernetes
- Talos Linux for immutable, secure nodes
- Cilium CNI for networking and security policies
- ArgoCD for GitOps workload management
- democratic-csi for TrueNAS storage integration

### Networking
- Private network: 10.9.8.0/24
- Pod CIDR: 10.244.0.0/16
- Service CIDR: 10.96.0.0/12
- Remote access: Tailscale only

### Storage
- TrueNAS Scale for shared storage
- NFS for ReadWriteMany workloads
- ZFS for data integrity

## Governance

- Constitution supersedes ad-hoc decisions
- Amendments require documentation update + PR approval
- All changes must reference relevant principles
- Complexity must be justified against these principles

**Version**: 1.0.0 | **Ratified**: 2025-12-24 | **Last Amended**: 2025-12-24
