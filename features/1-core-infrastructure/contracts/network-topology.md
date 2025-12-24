# Network Topology Contract

**Feature**: 1-core-infrastructure
**Date**: 2025-12-23
**Version**: 2.1 (Final Deployed State)
**Status**: ✅ DEPLOYED AND VALIDATED

## Deployment Summary

| Property | Value |
|----------|-------|
| Deployed | 2025-12-23 |
| Public IP | <VPS_PUBLIC_IP> |
| Tailscale IP | 100.84.93.46 |
| Proxmox Version | 9.1.2 |
| Kernel | 6.8.12-17-pve |
| Tailscale Version | 1.92.3 |

## Overview

This document defines the network architecture contract for the CloudEnv VPS infrastructure using Proxmox VE as the host OS with routed networking. All implementations MUST conform to this topology.

## Architecture Summary

- **Edge Protection**: SSDNodes provider firewall controls inbound traffic to public IP
- **Host Platform**: Proxmox VE 9.1.2 installed on Debian 13, manages all VMs
- **Routing**: Proxmox uses routed networking with NAT for VM traffic
- **VPN Access**: Tailscale runs directly on Proxmox host as subnet router
- **Internal Firewall**: Proxmox built-in firewall for VM isolation (future use)

## Network Segments

### Segment 1: Public Network (WAN)

| Property | Value |
|----------|-------|
| Purpose | Internet connectivity |
| Controlled By | Proxmox host (vmbr0) + Provider firewall |
| IP Assignment | Static or DHCP from SSDNodes |
| Expected IP | `<VPS_PUBLIC_IP>` (single public IPv4) |
| Devices | Proxmox host only |

**Contract**:
- Proxmox host owns the public IP on vmbr0
- Provider firewall filters all inbound traffic before reaching host
- Tailscale runs on host, accessible via tailnet
- Public IP may change on VPS reboot (DHCP)

### Segment 2: Private Network (LAN)

| Property | Value |
|----------|-------|
| Purpose | Internal VM communication |
| CIDR | `10.0.0.0/24` |
| Gateway | `10.0.0.1` (Proxmox vmbr1) |
| Proxmox Bridge | `vmbr1` (internal, no physical interface) |
| DHCP Range | `10.0.0.100 - 10.0.0.199` (via dnsmasq) |
| DNS | `10.0.0.1` (Proxmox dnsmasq) or external |
| Devices | All VMs |

**Contract**:
- All VMs connect to vmbr1
- Proxmox host provides NAT for VM internet access via nftables
- Static IPs for infrastructure: `10.0.0.2 - 10.0.0.49`
- DHCP for dynamic devices: `10.0.0.100 - 10.0.0.199`
- Reserved for future: `10.0.0.50 - 10.0.0.99`

### Segment 3: Tailscale Overlay

| Property | Value |
|----------|-------|
| Purpose | Secure remote access |
| Type | Mesh VPN overlay |
| Subnet Router | Proxmox host |
| Advertised Routes | `10.0.0.0/24` |
| Integration | Existing home tailnet |

**Contract**:
- Tailscale runs on Proxmox host
- Proxmox advertises private network (10.0.0.0/24) to tailnet
- Home devices access VPS private network via Tailscale → Proxmox routing
- Proxmox web UI accessible directly via Tailscale IP:8006

## IP Address Allocation

### Static Assignments (Reserved: 10.0.0.1 - 10.0.0.49)

| IP Address | Device | Purpose |
|------------|--------|---------|
| 10.0.0.1 | Proxmox vmbr1 | Gateway for VMs, NAT, DNS |
| 10.0.0.10-19 | Reserved | Future infrastructure services |
| 10.0.0.20-29 | Reserved | Database/storage services |
| 10.0.0.30-49 | Reserved | Future static allocations |

### DHCP Pool (10.0.0.100 - 10.0.0.199)

For dynamic devices, test VMs, and temporary allocations.

## Interface Mapping

### Proxmox Host Interfaces

| Interface | Bridge | Network | Purpose |
|-----------|--------|---------|---------|
| enp3s0 | - | Physical | Physical NIC (SSDNodes) |
| vmbr0 | Bridge | Public | WAN bridge, holds public IP `<VPS_PUBLIC_IP>/24` |
| vmbr1 | Bridge | 10.0.0.0/24 | Internal VM network, no physical ports |

**Proxmox `/etc/network/interfaces` Contract**:
```
auto lo
iface lo inet loopback

auto ens18
iface ens18 inet manual

auto vmbr0
iface vmbr0 inet static
    address <VPS_PUBLIC_IP>/24
    gateway <VPS_GATEWAY>
    bridge-ports enp3s0
    bridge-stp off
    bridge-fd 0

auto vmbr1
iface vmbr1 inet static
    address 10.0.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
    post-up iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o vmbr0 -j MASQUERADE
    post-down iptables -t nat -D POSTROUTING -s 10.0.0.0/24 -o vmbr0 -j MASQUERADE
```

### Tailscale Interface

| Interface | Network | Purpose |
|-----------|---------|---------|
| tailscale0 | 100.84.93.46/32 | VPN overlay on Proxmox host |

**Tailscale Configuration**:
- Runs as systemd service on Proxmox host
- Subnet router: advertises 10.0.0.0/24
- Hostname: `pve-vps`
- Version: 1.92.3

## Routing Tables

### Proxmox Host Routes

| Destination | Gateway | Interface | Metric | Purpose |
|-------------|---------|-----------|--------|---------|
| 0.0.0.0/0 | <VPS_GATEWAY> | vmbr0 | 0 | Default route to internet |
| <VPS_PUBLIC_SUBNET> | direct | vmbr0 | 0 | Public subnet |
| 10.0.0.0/24 | direct | vmbr1 | 0 | Private VM network |
| 100.64.0.0/10 | Tailscale | tailscale0 | 0 | Tailscale CGNAT range |

## DNS Configuration

| Property | Value |
|----------|-------|
| Proxmox DNS | External (Cloudflare 1.1.1.1) |
| VM DNS | 10.0.0.1 (Proxmox dnsmasq) or external |
| Upstream DNS | Cloudflare 1.1.1.1, 1.0.0.1 |
| Local Domain | `vps.local` (optional) |
| Resolution | VMs can use Proxmox or external DNS |

## Network Diagram

```
                                    ┌─────────────────────────────────────────────┐
                                    │               INTERNET                       │
                                    └─────────────────────┬───────────────────────┘
                                                          │
                                    ┌─────────────────────┴───────────────────────┐
                                    │         SSDNodes Provider Firewall          │
                                    │   (Default deny, allow SSH from admin IP)   │
                                    └─────────────────────┬───────────────────────┘
                                                          │
                                                          │ Public IPv4: <VPS_PUBLIC_IP>
                                                          │
┌─────────────────────────────────────────────────────────┴─────────────────────────────────────────────────────────┐
│                                    PROXMOX VE HOST (Debian 13)                                                     │
│                                                                                                                    │
│  enp3s0 ────► vmbr0 (<VPS_PUBLIC_IP>/24) ◄────────────────────────────────────────────────────────────────────┐     │
│               │      Default gateway: <VPS_GATEWAY>                                                           │     │
│               │                                                                                             │     │
│               │                                                                                             │     │
│               │  Tailscale (tailscale0) ─────► 100.x.x.x/32                                                │     │
│               │                                 Subnet router → advertises 10.0.0.0/24                      │     │
│               │                                                                                             │     │
│               │  ┌─────────────────────────────────────────────────────────────────────────────────────┐   │     │
│               │  │                          NAT (iptables MASQUERADE)                                   │   │     │
│               │  │                          IP Forwarding enabled                                       │   │     │
│               │  └─────────────────────────────────────────────────────────────────────────────────────┘   │     │
│               │                                        │                                                    │     │
│               └────────────────────────────────────────┼────────────────────────────────────────────────────┘     │
│                                                        │                                                          │
│               vmbr1 (10.0.0.1/24) ◄────────────────────┘                                                         │
│               │     (internal bridge, no physical ports)                                                          │
│               │     Gateway for all VMs                                                                           │
│               │                                                                                                   │
│               │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐                                │
│               └──┤  Future VM 1     │  │  Future VM 2     │  │  Future VM N     │                                │
│                  │  10.0.0.100      │  │  10.0.0.101      │  │  10.0.0.x        │                                │
│                  │  GW: 10.0.0.1    │  │  GW: 10.0.0.1    │  │  GW: 10.0.0.1    │                                │
│                  └──────────────────┘  └──────────────────┘  └──────────────────┘                                │
│                                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                          │
                                                          │ Tailscale (encrypted overlay)
                                                          │
                              ┌────────────────────────────┴────────────────────────────┐
                              │                    HOME NETWORK                          │
                              │                                                          │
                              │  OPNsense (home) ─► Tailscale ─► Routes to 10.0.0.0/24  │
                              │                                                          │
                              │  Workstation ─► Tailscale ─► Access to:                 │
                              │                              • Proxmox UI (100.x.x.x:8006)
                              │                              • All VMs on 10.0.0.x      │
                              └──────────────────────────────────────────────────────────┘
```

## Validation Checks

These assertions MUST pass for network contract compliance:

```yaml
# 1. Proxmox owns public IP
- assert: proxmox.vmbr0.ip == "<VPS_PUBLIC_IP>"

# 2. Provider firewall blocks unauthorized traffic
- assert: provider_firewall.default_policy == "deny"
- assert: provider_firewall.allow contains "ssh:admin_ip"

# 3. Proxmox vmbr1 is gateway for private network
- assert: proxmox.vmbr1.ip == "10.0.0.1"

# 4. VMs use Proxmox as gateway
- assert: future_vm.gateway == "10.0.0.1"

# 5. Tailscale routing on Proxmox host
- assert: tailscale.advertised_routes contains "10.0.0.0/24"
- assert: tailscale.running_on == "proxmox_host"

# 6. NAT enabled for VMs
- assert: iptables.nat.masquerade == "10.0.0.0/24"

# 7. Proxmox accessible via Tailscale
- assert: tailscale.can_reach("proxmox:8006") == true
```

## Security Boundaries

| Layer | Component | Responsibility |
|-------|-----------|----------------|
| 1 (Edge) | Provider Firewall | Block all except SSH from admin, ICMP |
| 2 (Host) | Proxmox iptables/nftables | NAT, host-level protection |
| 3 (Internal) | Proxmox Firewall | Inter-VM isolation rules |
| 4 (VPN) | Tailscale | Encrypted tunnel to home network |

## Failure Scenarios

| Scenario | Impact | Recovery |
|----------|--------|----------|
| Provider firewall misconfigured | SSH access lost | Fix via SSDNodes portal/API |
| Tailscale disconnected | Remote access lost, SSH still works | Reconnect via direct SSH |
| NAT misconfigured | VMs lose internet access | Fix iptables rules on host |
| Proxmox host down | Everything down | VPS console via SSDNodes portal |
