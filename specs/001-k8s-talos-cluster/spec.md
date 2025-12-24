# Feature Specification: Kubernetes Cluster with Talos Linux

**Feature Branch**: `001-k8s-talos-cluster`
**Created**: 2025-12-24
**Status**: Draft
**Input**: Deploy 3-node Talos Linux Kubernetes cluster with TrueNAS Scale storage and ArgoCD for GitOps

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Bootstrap Kubernetes Cluster (Priority: P1)

As an operator, I want to deploy a production-ready Kubernetes cluster on my Proxmox VPS so that I have a platform for running containerized workloads with high availability.

**Why this priority**: Foundation for all subsequent infrastructure. Nothing else can be deployed without a functioning cluster.

**Independent Test**: Cluster is operational when `kubectl get nodes` returns 3 Ready nodes and `kubectl get pods -A` shows all system pods Running.

**Acceptance Scenarios**:

1. **Given** Proxmox host with sufficient resources, **When** I run the Talos bootstrap process, **Then** 3 control-plane nodes form a cluster within 10 minutes
2. **Given** bootstrapped cluster, **When** I run `kubectl get nodes`, **Then** all nodes show `Ready` status
3. **Given** running cluster, **When** one node is rebooted, **Then** cluster remains operational and node rejoins automatically

---

### User Story 2 - Shared Storage for HA Workloads (Priority: P1)

As an operator, I want TrueNAS Scale providing NFS/iSCSI storage so that pods can be rescheduled across nodes without data loss.

**Why this priority**: Critical for HA - without shared storage, pods are pinned to nodes and cannot failover.

**Independent Test**: Create a PVC, write data from pod on node1, delete pod, verify data accessible from pod on node2.

**Acceptance Scenarios**:

1. **Given** TrueNAS Scale VM is running, **When** Kubernetes CSI driver attempts to provision a PVC, **Then** storage is allocated within 30 seconds
2. **Given** a pod with PVC running on node1, **When** node1 is cordoned and pod rescheduled to node2, **Then** pod starts with data intact
3. **Given** TrueNAS pool at 80% capacity, **When** new PVC is requested, **Then** appropriate warning is logged

---

### User Story 3 - GitOps Deployment with ArgoCD (Priority: P2)

As an operator, I want ArgoCD deployed and configured so that I can manage all cluster workloads declaratively through Git.

**Why this priority**: Enables infrastructure-as-code workflow. Depends on P1 stories being complete.

**Independent Test**: Push manifest to Git repo, verify ArgoCD auto-syncs and deploys the application.

**Acceptance Scenarios**:

1. **Given** ArgoCD is installed, **When** I access the ArgoCD UI, **Then** I can authenticate and view cluster state
2. **Given** an Application CR pointing to a Git repo, **When** I commit a new manifest, **Then** ArgoCD syncs within 3 minutes
3. **Given** a deployed application, **When** I modify the Git manifest, **Then** ArgoCD detects drift and offers sync

---

### User Story 4 - Secure Remote Access (Priority: P2)

As an operator, I want to access the Kubernetes API and ArgoCD UI securely via Tailscale so that cluster management doesn't require VPN tunnels or public exposure.

**Why this priority**: Enables day-2 operations. Builds on existing Tailscale infrastructure from Feature 2.

**Independent Test**: From Tailscale-connected device, successfully run `kubectl get nodes` and access ArgoCD UI.

**Acceptance Scenarios**:

1. **Given** cluster is running, **When** I configure kubectl with Tailscale IP endpoint, **Then** API requests succeed from any Tailscale device
2. **Given** ArgoCD ingress via Tailscale, **When** I access the UI from remote device, **Then** login page loads over HTTPS
3. **Given** non-Tailscale network, **When** attempting to reach cluster API, **Then** connection is refused

---

### User Story 5 - Cluster Monitoring Foundation (Priority: P3)

As an operator, I want basic cluster health metrics visible so that I can detect resource exhaustion and node issues.

**Why this priority**: Important for operations but cluster functions without it. Enables proactive management.

**Independent Test**: Access metrics dashboard showing node CPU/RAM/disk utilization.

**Acceptance Scenarios**:

1. **Given** metrics stack is deployed, **When** I query Prometheus, **Then** node_exporter metrics are available
2. **Given** a node approaching resource limits, **When** threshold is crossed, **Then** alert fires
3. **Given** Grafana is accessible, **When** I load node dashboard, **Then** real-time metrics display

---

### Edge Cases

- What happens when TrueNAS VM is unavailable? → Pods with PVCs enter Pending state; existing mounted volumes become read-only after timeout
- What happens when 2 of 3 control-plane nodes fail? → Cluster loses quorum, becomes read-only until majority restored
- How does system handle Proxmox host reboot? → All VMs restart; Talos auto-recovers cluster state; may take 5-10 minutes
- What happens when disk space exhausted on Talos node? → Kubelet evicts pods; node may become NotReady

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy 3 Talos Linux VMs with control-plane roles on Proxmox
- **FR-002**: System MUST configure etcd with 3-node quorum for fault tolerance
- **FR-003**: System MUST deploy TrueNAS Scale VM with NFS share for Kubernetes PVs
- **FR-004**: System MUST install democratic-csi or equivalent CSI driver for TrueNAS integration
- **FR-005**: System MUST deploy ArgoCD as first GitOps-managed workload
- **FR-006**: System MUST expose Kubernetes API via Tailscale-accessible endpoint
- **FR-007**: System MUST persist all cluster configuration in Git repository
- **FR-008**: System MUST use Talos machine configuration for immutable, API-driven management
- **FR-009**: System MUST configure CNI (Cilium preferred) for pod networking
- **FR-010**: System MUST implement Pod Security Standards (baseline minimum)

### Non-Functional Requirements

- **NFR-001**: Cluster MUST recover from single node failure without manual intervention
- **NFR-002**: Control plane MUST remain responsive with <500ms API latency under normal load
- **NFR-003**: TrueNAS storage MUST provide >100 IOPS per PVC
- **NFR-004**: All secrets MUST be encrypted at rest (Talos default + sealed-secrets or SOPS)
- **NFR-005**: System MUST boot to operational state within 10 minutes after host restart

### Key Entities

- **Talos Node**: Immutable Linux OS running Kubernetes components; configured via machine config YAML
- **TrueNAS Pool**: ZFS storage pool providing NFS/iSCSI backends; hosts PersistentVolumes
- **ArgoCD Application**: Kubernetes CR defining Git→Cluster sync; manages workload lifecycle
- **Machine Configuration**: Talos-specific YAML defining node identity, network, and cluster membership

## Resource Allocation

### VM Specifications

| VM | vCPU | RAM | Disk | IP Assignment |
|----|------|-----|------|---------------|
| talos-cp-1 | 3 | 14GB | 50GB | 10.9.8.11 |
| talos-cp-2 | 3 | 14GB | 50GB | 10.9.8.12 |
| talos-cp-3 | 3 | 14GB | 50GB | 10.9.8.13 |
| truenas-scale | 2 | 16GB | 100GB (OS) + 200GB (pool) | 10.9.8.20 |

### Network Design

- **Cluster Network**: 10.9.8.0/24 (virbr1, existing from Feature 1)
- **Pod CIDR**: 10.244.0.0/16
- **Service CIDR**: 10.96.0.0/12
- **Kubernetes API VIP**: 10.9.8.100 (via kube-vip or similar)

### Host Resource Summary

| Resource | Total | Allocated | Remaining |
|----------|-------|-----------|-----------|
| vCPU | 12 | 11 | 1 |
| RAM | 62.8GB | 58GB | 4.8GB |

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 3/3 Kubernetes nodes report Ready status for >99% of time over 7-day period
- **SC-002**: Pod scheduled with PVC successfully starts on any available node within 60 seconds
- **SC-003**: ArgoCD syncs Git changes to cluster within 3 minutes of commit
- **SC-004**: Cluster recovers to full operation within 15 minutes after host reboot
- **SC-005**: kubectl commands complete with <500ms latency from Tailscale-connected device
- **SC-006**: Zero secrets stored in plaintext in Git repository

## Dependencies

- **Feature 1**: Core infrastructure (Proxmox, networking) - COMPLETE
- **Feature 2**: Tailscale ACL configuration - COMPLETE
- **External**: Talos Linux images, TrueNAS Scale ISO, ArgoCD Helm chart
