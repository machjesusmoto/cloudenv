# Research: Core Infrastructure Setup

**Feature**: 1-core-infrastructure
**Date**: 2025-12-16
**Status**: Complete

## Technology Decisions

### 1. Hypervisor Layer

**Decision**: KVM/QEMU with libvirt

**Rationale**:
- Native Linux virtualization with kernel-level performance
- libvirt provides stable API for Terraform/Ansible automation
- No additional licensing; open source stack
- Well-documented, mature ecosystem
- SSDNodes VPS has passthrough virtualization enabled

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Proxmox as host OS | Would require temporary public exposure of Proxmox during setup; violates Constitution I (Security-First) |
| VMware ESXi | Licensing complexity; overkill for 2 VMs |
| Docker/containers | OPNsense and Proxmox require full VM capabilities |

### 2. Infrastructure as Code Tooling

**Decision**: Terraform + Ansible (combined approach)

**Rationale**:
- **Terraform**: Declarative infrastructure provisioning via libvirt provider
  - Manages VM lifecycle, storage pools, network definitions
  - State file tracks infrastructure drift
  - Idempotent by design
- **Ansible**: Configuration management and orchestration
  - Agentless (SSH-based) - no software on target VMs
  - Excellent for OPNsense configuration (REST API modules exist)
  - Ansible Vault for secrets management
- **Separation of concerns**: Terraform "what exists", Ansible "how it's configured"

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Ansible only | Would need custom modules for VM creation; Terraform's libvirt provider is more mature |
| Terraform only | Poor at imperative configuration tasks (OPNsense API calls, service restarts) |
| Shell scripts only | Not declarative; hard to maintain idempotency; Constitution III violation |
| Pulumi | Adds programming language complexity; Terraform more established for libvirt |

### 3. Base Operating System

**Decision**: Ubuntu 22.04 LTS (Jammy)

**Rationale**:
- Long-term support until 2027 (security updates until 2032)
- Excellent libvirt/KVM support in default repositories
- SSDNodes likely offers Ubuntu as default image
- Wide community support and documentation
- Predictable apt package management

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Debian 12 | Slightly older packages; Ubuntu has better cloud-init integration |
| Rocky Linux 9 | Less familiar; different package manager |
| Alpine Linux | Too minimal; missing enterprise tooling |

### 4. OPNsense Deployment Method

**Decision**: OPNsense VM with cloud-init + Ansible configuration

**Rationale**:
- Download official OPNsense nano image (designed for VMs)
- Cloud-init for initial bootstrap (SSH keys, network)
- Ansible with `opnsense` collection for ongoing configuration
- OPNsense REST API enables declarative firewall rule management

**Key Considerations**:
- OPNsense will require 2 vNICs: WAN (bridged to public) and LAN (internal network)
- Initial SSH access required for Ansible; disabled after Tailscale operational
- Firewall rules managed via Ansible to ensure version control

### 5. Proxmox VE Deployment Method

**Decision**: Proxmox ISO install via libvirt, Ansible post-config

**Rationale**:
- Proxmox provides official ISO with all dependencies
- Automated install via preseed/autoinstall where possible
- Ansible for post-install configuration (storage, networking, backups)
- No public interface ever - only reachable via Tailscale

**Resource Allocation**:
- 8 vCPU (leaves 4 for OPNsense + host overhead)
- 48GB RAM (leaves 16GB for OPNsense + host)
- 800GB storage pool (leaves 400GB for OPNsense + host + images)

### 6. Tailscale Integration Strategy

**Decision**: Tailscale on OPNsense as subnet router

**Rationale**:
- OPNsense has official Tailscale plugin
- Configure OPNsense to advertise VPS private subnet (10.0.0.0/24) to tailnet
- Home devices access Proxmox via Tailscale → OPNsense → private subnet
- Automatic reconnection; NAT traversal handled by Tailscale

**Implementation**:
1. Install Tailscale plugin on OPNsense via Ansible
2. Authenticate with Tailscale using pre-generated auth key
3. Enable subnet routing for 10.0.0.0/24
4. Approve routes in Tailscale admin console (can be automated via API)

**Alternatives Considered**:
| Alternative | Why Rejected |
|-------------|--------------|
| Tailscale on Proxmox directly | OPNsense should own all network ingress/egress per Constitution I |
| Tailscale on host OS | Adds unnecessary complexity; OPNsense is the designated network gateway |
| WireGuard native | More manual configuration; Tailscale already in use with established tailnet |

### 7. Network Architecture

**Decision**: Two libvirt networks

**Design**:
```
Internet ──► Public IPv4 ──► Bridge (br0) ──► OPNsense WAN (vtnet0)
                                              │
                                              ▼
                              OPNsense LAN (vtnet1) ──► Private Network (10.0.0.0/24)
                                              │                    │
                                              │                    ▼
                                              │              Proxmox (10.0.0.10)
                                              │
                                              ▼
                              Tailscale ──► Home Network (existing tailnet)
```

**IP Allocation**:
| Device | Interface | IP Address |
|--------|-----------|------------|
| Host OS | eth0 | Public IP (DHCP from provider) |
| OPNsense | vtnet0 (WAN) | Public IP (macvtap passthrough) |
| OPNsense | vtnet1 (LAN) | 10.0.0.1 |
| OPNsense | Tailscale | 100.x.x.x (assigned by Tailscale) |
| Proxmox | eth0 | 10.0.0.10 |

### 8. Secret Management

**Decision**: Ansible Vault + environment variables

**Rationale**:
- Ansible Vault encrypts secrets at rest in Git
- Vault password via environment variable or file (not in repo)
- Tailscale auth keys generated per deployment, short-lived

**Secrets to Manage**:
- SSH private key (for initial access)
- Ansible Vault password
- Tailscale auth key (ephemeral, single-use)
- OPNsense root password (generated, stored in vault)
- Proxmox root password (generated, stored in vault)

### 9. Testing Strategy

**Decision**: Layered validation approach

**Layers**:
1. **Static Analysis**: `terraform validate`, `ansible-lint`, `yamllint`
2. **Dry Run**: `terraform plan`, `ansible --check`
3. **Connectivity Tests**: Ansible playbook asserting network reachability
4. **Security Tests**: Port scanning to verify default-deny

**Test Cases**:
- OPNsense WAN responds to ICMP (if allowed by policy)
- OPNsense blocks unauthorized ports
- Proxmox web UI accessible from Tailscale IP
- Home device can SSH to Proxmox via Tailscale
- Public IP scanning shows only OPNsense-permitted services

## Open Questions Resolved

| Question | Resolution |
|----------|------------|
| VPN Protocol | Tailscale (per spec FR-004) |
| Hypervisor | KVM/QEMU with libvirt (user selected) |
| IaC Tooling | Terraform + Ansible (user selected) |
| Base OS | Ubuntu 22.04 LTS (best cloud support) |

## References

- [OPNsense Documentation](https://docs.opnsense.org/)
- [Terraform libvirt Provider](https://registry.terraform.io/providers/dmacvicar/libvirt/latest/docs)
- [Ansible OPNsense Collection](https://galaxy.ansible.com/ansibleguy/opnsense)
- [Tailscale Subnet Routing](https://tailscale.com/kb/1019/subnets)
- [Proxmox VE Documentation](https://pve.proxmox.com/wiki/Main_Page)
