# Firewall Rules Contract

**Feature**: 1-core-infrastructure
**Date**: 2025-12-16
**Version**: 1.0

## Overview

This document defines the firewall rule contract for OPNsense. All implementations MUST conform to these security requirements per Constitution Principle I (Security-First Design).

## Default Policy

| Interface | Direction | Default Action |
|-----------|-----------|----------------|
| WAN | Inbound | **BLOCK ALL** |
| WAN | Outbound | ALLOW (stateful) |
| LAN | Inbound | ALLOW to gateway services |
| LAN | Outbound | ALLOW |
| Tailscale | Inbound | ALLOW from tailnet |
| Tailscale | Outbound | ALLOW |

**Principle**: Default deny on WAN. All inbound access must be explicitly permitted.

## WAN Interface Rules

### Inbound Rules (from Internet)

| Order | Action | Protocol | Source | Dest Port | Description |
|-------|--------|----------|--------|-----------|-------------|
| 1 | BLOCK | any | RFC1918 | any | Block private IP spoofing |
| 2 | BLOCK | any | Bogons | any | Block bogon networks |
| 3 | PASS | ICMP | any | echo-request | Allow ping (optional) |
| 4 | PASS | UDP | any | 41641 | Tailscale direct (optional) |
| 100 | BLOCK | any | any | any | Default deny (implicit) |

**Notes**:
- Rule 3 (ICMP) is optional; useful for diagnostics
- Rule 4 (Tailscale UDP) optional; Tailscale works via DERP relay if blocked
- SSH is NOT permitted on WAN per Constitution (access via Tailscale only)

### Outbound Rules (to Internet)

| Order | Action | Protocol | Source | Dest | Description |
|-------|--------|----------|--------|------|-------------|
| 1 | PASS | any | LAN net | any | NAT outbound for private network |
| 2 | PASS | any | This Firewall | any | Firewall own traffic (updates, NTP) |

## LAN Interface Rules

### Inbound Rules (from Private Network)

| Order | Action | Protocol | Source | Dest Port | Description |
|-------|--------|----------|--------|-----------|-------------|
| 1 | PASS | TCP | LAN net | 22 | SSH to firewall (management) |
| 2 | PASS | TCP | LAN net | 443 | HTTPS to firewall (web UI) |
| 3 | PASS | UDP | LAN net | 53 | DNS queries |
| 4 | PASS | TCP | LAN net | 53 | DNS queries (TCP) |
| 5 | PASS | UDP | LAN net | 123 | NTP queries |
| 6 | PASS | any | LAN net | any | Allow LAN to internet (via NAT) |

### Inter-LAN Rules

| Order | Action | Protocol | Source | Destination | Description |
|-------|--------|----------|--------|-------------|-------------|
| 1 | PASS | any | LAN net | LAN net | Allow inter-VM communication |

## Tailscale Interface Rules

### Inbound Rules (from Tailnet)

| Order | Action | Protocol | Source | Dest | Description |
|-------|--------|----------|--------|------|-------------|
| 1 | PASS | TCP | Tailscale net | LAN net:22 | SSH to private VMs |
| 2 | PASS | TCP | Tailscale net | LAN net:443 | HTTPS to private services |
| 3 | PASS | TCP | Tailscale net | LAN net:8006 | Proxmox web UI |
| 4 | PASS | TCP | Tailscale net | LAN net:3128 | Proxmox SPICE proxy |
| 5 | PASS | TCP | Tailscale net | LAN net:5900-5999 | VNC consoles |
| 6 | PASS | ICMP | Tailscale net | LAN net | Ping for diagnostics |
| 10 | PASS | any | Tailscale net | LAN net | Allow all tailnet to private |

**Note**: Rule 10 is permissive. Can be tightened based on operational needs.

### Outbound Rules (to Tailnet)

| Order | Action | Protocol | Source | Dest | Description |
|-------|--------|----------|--------|------|-------------|
| 1 | PASS | any | LAN net | Tailscale net | Allow private to tailnet |

## NAT Rules

### Outbound NAT (Source NAT)

| Interface | Source | Translation | Description |
|-----------|--------|-------------|-------------|
| WAN | LAN net | WAN address | Private network internet access |

### Port Forwarding (Destination NAT)

**Default**: None. All access via Tailscale.

| Rule | Protocol | WAN Port | Dest | Description |
|------|----------|----------|------|-------------|
| (none) | - | - | - | No port forwards per Constitution |

**Note**: Port forwarding is prohibited. Public exposure of services violates Constitution I.

## Aliases

| Alias Name | Type | Value | Description |
|------------|------|-------|-------------|
| LAN_net | Network | 10.0.0.0/24 | Private network |
| Tailscale_net | Network | 100.64.0.0/10 | Tailscale CGNAT range |
| Proxmox_IP | Host | 10.0.0.10 | Proxmox VE server |
| Management_Ports | Port | 22, 443, 8006 | Common management ports |
| RFC1918 | Network | 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 | Private ranges |

## Security Hardening

### Anti-Spoofing

- Block packets with private source IPs on WAN
- Block bogon networks on WAN
- Enable unicast reverse path verification

### Rate Limiting

| Rule | Limit | Description |
|------|-------|-------------|
| SSH | 10/minute | Prevent brute force |
| ICMP | 50/second | Prevent ping flood |
| New connections | 1000/second | General DoS protection |

### Logging Requirements

| Traffic Type | Log Level |
|--------------|-----------|
| Blocked WAN inbound | LOG |
| Allowed SSH | LOG |
| Blocked by default rules | LOG (sampled) |
| Normal LAN traffic | NO LOG |

## Validation Checks

These assertions MUST pass for firewall contract compliance:

```yaml
# 1. Default deny on WAN
- assert: wan.default_policy == "block"

# 2. No SSH on WAN
- assert: wan.rules not contains { port: 22, action: "pass" }

# 3. No port forwarding
- assert: nat.port_forwards == []

# 4. Tailscale can reach Proxmox
- assert: tailscale.rules contains { dest: "10.0.0.10", port: 8006, action: "pass" }

# 5. Private network can reach internet
- assert: lan.rules contains { dest: "any", action: "pass" }

# 6. Logging enabled for blocked traffic
- assert: logging.blocked_wan == true
```

## Rule Change Process

Per Constitution Governance:

1. All firewall rule changes MUST be made via Ansible (IaC)
2. Changes MUST be committed to Git with rationale
3. Emergency changes require post-hoc documentation within 24 hours
4. Rule additions require Constitution compliance check
