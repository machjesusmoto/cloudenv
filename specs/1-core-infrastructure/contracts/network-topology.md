# Network Topology Contract

**Feature**: 1-core-infrastructure
**Date**: 2025-12-16
**Version**: 1.0

## Overview

This document defines the network architecture contract for the CloudEnv VPS infrastructure. All implementations MUST conform to this topology.

## Network Segments

### Segment 1: Public Network (WAN)

| Property | Value |
|----------|-------|
| Purpose | Internet connectivity |
| Controlled By | OPNsense WAN interface |
| IP Assignment | DHCP from SSDNodes |
| Expected IP | Single public IPv4 |
| Devices | OPNsense only |

**Contract**:
- ONLY OPNsense may have direct public IP attachment
- All other devices MUST be NAT'd through OPNsense
- Public IP may change on VPS reboot (DHCP)

### Segment 2: Private Network (LAN)

| Property | Value |
|----------|-------|
| Purpose | Internal VM communication |
| CIDR | `10.0.0.0/24` |
| Gateway | `10.0.0.1` (OPNsense) |
| DHCP Range | `10.0.0.100 - 10.0.0.199` |
| DNS | `10.0.0.1` (OPNsense) |
| Devices | OPNsense LAN, Proxmox, future VMs |

**Contract**:
- All private devices MUST use OPNsense as gateway
- Static IPs for infrastructure: `10.0.0.1 - 10.0.0.49`
- DHCP for dynamic devices: `10.0.0.100 - 10.0.0.199`
- Reserved for future: `10.0.0.50 - 10.0.0.99`

### Segment 3: Tailscale Overlay

| Property | Value |
|----------|-------|
| Purpose | Secure remote access |
| Type | Mesh VPN overlay |
| Subnet Router | OPNsense |
| Advertised Routes | `10.0.0.0/24` |
| Integration | Existing home tailnet |

**Contract**:
- Tailscale runs ONLY on OPNsense
- OPNsense advertises private network to tailnet
- Home devices access VPS private network via Tailscale → OPNsense routing

## IP Address Allocation

### Static Assignments (Reserved: 10.0.0.1 - 10.0.0.49)

| IP Address | Device | Purpose |
|------------|--------|---------|
| 10.0.0.1 | OPNsense | Gateway, DNS, Tailscale router |
| 10.0.0.10 | Proxmox VE | Virtualization platform |
| 10.0.0.11-19 | Reserved | Future Proxmox cluster nodes |
| 10.0.0.20-29 | Reserved | Future infrastructure services |
| 10.0.0.30-49 | Reserved | Future static allocations |

### DHCP Pool (10.0.0.100 - 10.0.0.199)

For dynamic devices, test VMs, and temporary allocations.

## Interface Mapping

### OPNsense Interfaces

| Interface | Name | Network | Purpose |
|-----------|------|---------|---------|
| vtnet0 | WAN | Public | Internet gateway |
| vtnet1 | LAN | 10.0.0.0/24 | Private network |
| tailscale0 | Tailscale | 100.x.x.x/32 | VPN overlay |

### Proxmox Interfaces

| Interface | Name | Network | Purpose |
|-----------|------|---------|---------|
| eth0 | vmbr0 | 10.0.0.0/24 | Management + VM bridge |

## Routing Table

### OPNsense Routes

| Destination | Gateway | Interface | Metric |
|-------------|---------|-----------|--------|
| 0.0.0.0/0 | Provider GW | WAN | 1 |
| 10.0.0.0/24 | direct | LAN | 0 |
| 100.64.0.0/10 | Tailscale | tailscale0 | 0 |

### Proxmox Routes

| Destination | Gateway | Interface | Metric |
|-------------|---------|-----------|--------|
| 0.0.0.0/0 | 10.0.0.1 | eth0 | 1 |
| 10.0.0.0/24 | direct | eth0 | 0 |

## DNS Configuration

| Property | Value |
|----------|-------|
| Primary DNS | 10.0.0.1 (OPNsense Unbound) |
| Upstream DNS | Configurable (default: Cloudflare 1.1.1.1) |
| Local Domain | `vps.local` (optional) |
| Resolution | OPNsense resolves local names |

## Network Diagram

```
                                    ┌─────────────────────────────────┐
                                    │          INTERNET               │
                                    └───────────────┬─────────────────┘
                                                    │
                                                    │ Public IPv4
                                                    │
                              ┌─────────────────────┴─────────────────────┐
                              │              VPS HOST (Ubuntu)            │
                              │                                           │
                              │  ┌───────────────────────────────────┐   │
                              │  │         OPNsense VM               │   │
                              │  │                                   │   │
                              │  │  WAN ──────► Public IP            │   │
                              │  │  (vtnet0)    (macvtap bridge)     │   │
                              │  │                                   │   │
                              │  │  LAN ──────► 10.0.0.1             │   │
                              │  │  (vtnet1)    (virbr1)             │   │
                              │  │                                   │   │
                              │  │  Tailscale ► 100.x.x.x            │   │
                              │  │  (overlay)   subnet router        │   │
                              │  └────────────────┬──────────────────┘   │
                              │                   │                       │
                              │                   │ 10.0.0.0/24           │
                              │                   │ (virbr1)              │
                              │                   │                       │
                              │  ┌────────────────┴──────────────────┐   │
                              │  │         Proxmox VM                │   │
                              │  │         10.0.0.10                 │   │
                              │  │                                   │   │
                              │  │  ┌──────────┐  ┌──────────┐      │   │
                              │  │  │  VM 1    │  │  VM 2    │ ...  │   │
                              │  │  │10.0.0.x  │  │10.0.0.y  │      │   │
                              │  │  └──────────┘  └──────────┘      │   │
                              │  └──────────────────────────────────┘   │
                              └───────────────────────────────────────────┘
                                                    │
                                                    │ Tailscale (encrypted)
                                                    │
                              ┌─────────────────────┴─────────────────────┐
                              │              HOME NETWORK                 │
                              │                                           │
                              │  OPNsense ─► Tailscale ─► 10.0.0.0/24    │
                              │  (home)       (routes)    (VPS access)   │
                              │                                           │
                              │  Workstation ─► Tailscale ─► Proxmox UI  │
                              │                             (10.0.0.10)  │
                              └───────────────────────────────────────────┘
```

## Validation Checks

These assertions MUST pass for network contract compliance:

```yaml
# 1. OPNsense owns public IP
- assert: opnsense.wan_ip == vps.public_ip

# 2. Private network isolated
- assert: proxmox.public_ip == null

# 3. Gateway correct
- assert: proxmox.gateway == "10.0.0.1"

# 4. Tailscale routing
- assert: tailscale.advertised_routes contains "10.0.0.0/24"

# 5. DNS resolution
- assert: proxmox.dns == "10.0.0.1"
```
