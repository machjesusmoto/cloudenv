# Data Model: Core Infrastructure Setup

**Feature**: 1-core-infrastructure
**Date**: 2025-12-16

## Infrastructure Entities

This document defines the logical entities managed by the IaC codebase. These map to Terraform resources and Ansible configuration targets.

### 1. VPS Host

The physical SSDNodes VPS running Ubuntu 22.04 as the hypervisor host.

| Attribute | Type | Description | Source |
|-----------|------|-------------|--------|
| hostname | string | Host FQDN | Variable: `vps_hostname` |
| public_ip | string | Provider-assigned IPv4 | DHCP (eth0) |
| vcpus | integer | Total vCPU count | 12 (fixed) |
| memory_gb | integer | Total RAM in GB | 64 (fixed) |
| storage_gb | integer | NVMe capacity in GB | 1200 (fixed) |
| ssh_port | integer | SSH listen port | Variable: `ssh_port` (default: 22) |

**State**: Managed by provider; Terraform references but doesn't create.

### 2. Libvirt Storage Pool

Storage backend for VM disk images.

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| name | string | Pool identifier | `default` |
| type | enum | Pool type | `dir` |
| path | string | Filesystem path | `/var/lib/libvirt/images` |
| capacity_gb | integer | Allocated capacity | 1000 |

**Relationships**: Contains VM disk volumes.

### 3. Libvirt Network (Private)

Internal network connecting OPNsense LAN to Proxmox.

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| name | string | Network identifier | `vmnet-private` |
| mode | enum | Network mode | `nat` (initially) → `none` (after OPNsense) |
| bridge | string | Bridge device name | `virbr1` |
| cidr | string | Network CIDR | `10.0.0.0/24` |
| dhcp_enabled | boolean | DHCP via libvirt | `false` (OPNsense provides DHCP) |
| gateway | string | Default gateway | `10.0.0.1` (OPNsense) |

**Relationships**: Connected to OPNsense LAN interface, Proxmox interface.

### 4. OPNsense VM

Firewall/router virtual machine.

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| name | string | VM identifier | `opnsense` |
| vcpus | integer | Allocated vCPUs | 2 |
| memory_mb | integer | Allocated RAM (MB) | 4096 |
| disk_gb | integer | Root disk size (GB) | 32 |
| wan_interface | string | WAN network attachment | `macvtap` to eth0 |
| lan_interface | string | LAN network attachment | `vmnet-private` |
| wan_ip | string | WAN IP address | Public IP (DHCP) |
| lan_ip | string | LAN IP address | `10.0.0.1` |
| console | enum | Console type | `vnc` |

**States**:
- `provisioning`: VM created, OS installing
- `configuring`: Ansible applying configuration
- `operational`: Firewall active, Tailscale connected
- `failed`: Error state requiring intervention

**Relationships**:
- Owns public IP exclusively
- Gateway for private network
- Tailscale subnet router

### 5. Proxmox VM

Virtualization platform virtual machine.

| Attribute | Type | Description | Default |
|-----------|------|-------------|---------|
| name | string | VM identifier | `proxmox` |
| vcpus | integer | Allocated vCPUs | 8 |
| memory_mb | integer | Allocated RAM (MB) | 49152 (48GB) |
| disk_gb | integer | Root disk size (GB) | 100 |
| data_disk_gb | integer | VM storage disk (GB) | 700 |
| interface | string | Network attachment | `vmnet-private` |
| ip_address | string | Static IP | `10.0.0.10` |
| gateway | string | Default gateway | `10.0.0.1` |
| web_port | integer | Web UI port | 8006 |
| console | enum | Console type | `vnc` |

**States**:
- `provisioning`: VM created, OS installing
- `configuring`: Ansible applying configuration
- `operational`: Web UI accessible, storage configured
- `failed`: Error state requiring intervention

**Relationships**:
- Routes through OPNsense for internet
- Accessible via Tailscale through OPNsense subnet routing

### 6. Tailscale Node

OPNsense's Tailscale identity on the tailnet.

| Attribute | Type | Description | Source |
|-----------|------|-------------|--------|
| hostname | string | Tailscale device name | `opnsense-vps` |
| tailscale_ip | string | Assigned Tailscale IP | Auto (100.x.x.x) |
| advertised_routes | list[string] | Subnet routes | `["10.0.0.0/24"]` |
| exit_node | boolean | Act as exit node | `false` |
| auth_key | string | Authentication key | Variable (Vault) |

**States**:
- `disconnected`: Not authenticated
- `connecting`: Auth in progress
- `connected`: Active on tailnet
- `needs_approval`: Subnet routes pending admin approval

**Relationships**:
- Runs on OPNsense
- Member of existing tailnet
- Advertises private network to tailnet

### 7. Firewall Rule Set

OPNsense firewall configuration.

| Attribute | Type | Description |
|-----------|------|-------------|
| interface | enum | `WAN`, `LAN`, `Tailscale` |
| direction | enum | `in`, `out` |
| action | enum | `pass`, `block`, `reject` |
| protocol | enum | `tcp`, `udp`, `icmp`, `any` |
| source | string | Source IP/network/alias |
| destination | string | Destination IP/network/alias |
| port | string | Port or range |
| description | string | Rule documentation |
| enabled | boolean | Rule active state |
| order | integer | Processing priority |

**Default Policy**: Block all, explicit allow rules only.

## Entity Relationships

```
┌─────────────────┐
│    VPS Host     │
│  (Ubuntu 22.04) │
└────────┬────────┘
         │ hosts
         ▼
┌─────────────────┐      ┌─────────────────┐
│  Storage Pool   │◄─────│ Libvirt Network │
│   (1000 GB)     │      │  (10.0.0.0/24)  │
└────────┬────────┘      └────────┬────────┘
         │ contains               │ connects
         ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│   OPNsense VM   │◄────►│   Proxmox VM    │
│  (10.0.0.1)     │      │  (10.0.0.10)    │
└────────┬────────┘      └─────────────────┘
         │ runs
         ▼
┌─────────────────┐
│ Tailscale Node  │
│ (subnet router) │
└────────┬────────┘
         │ advertises
         ▼
┌─────────────────┐
│ Home Tailnet    │
│ (existing)      │
└─────────────────┘
```

## Terraform Resource Mapping

| Entity | Terraform Resource |
|--------|-------------------|
| Storage Pool | `libvirt_pool.default` |
| Private Network | `libvirt_network.private` |
| OPNsense VM | `libvirt_domain.opnsense` |
| Proxmox VM | `libvirt_domain.proxmox` |
| OPNsense Disk | `libvirt_volume.opnsense_root` |
| Proxmox Disks | `libvirt_volume.proxmox_root`, `libvirt_volume.proxmox_data` |

## Ansible Inventory Mapping

| Entity | Inventory Group | Host |
|--------|-----------------|------|
| VPS Host | `hypervisors` | `vps.example.com` |
| OPNsense | `firewalls` | `10.0.0.1` (via host jump) |
| Proxmox | `proxmox` | `10.0.0.10` (via Tailscale) |
