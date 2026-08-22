# Feature 2: Tailscale ACL Configuration - Solution

**Status**: ✅ Complete
**Date**: 2025-12-23

## Problem Statement

When Tailscale `--accept-routes` is enabled, traffic to home LAN subnets (192.168.x.x) hairpins through Tailscale instead of using the local network path, even when devices are on the same LAN.

## Root Cause

Tailscale uses **policy-based routing** with `ip rule` to direct traffic:

```
5270: from all lookup 52
32766: from all lookup main
```

When `--accept-routes` is enabled, Tailscale populates **table 52** with all advertised subnet routes. Since rule 5270 is evaluated **before** rule 32766 (main table), Tailscale's routes always take precedence, regardless of route metrics in the main table.

## Solution

Add higher-priority ip rules (priority 5200) that force local subnet traffic to use the main routing table **before** Tailscale's table 52:

```bash
ip rule add to 192.168.3.0/24 lookup main priority 5200
# ... repeat for each home subnet
```

This ensures:
1. Traffic to home LAN subnets → main table → local gateway
2. Traffic to cloudenv (10.0.0.0/24) → table 52 → Tailscale → pve-vps

## Implementation

### ACL Policy Applied

The following ACL policy was applied via Tailscale API:

**Tag Structure**:
- `tag:network-homenet` - Devices on home network
- `tag:network-cloud` - CloudEnv infrastructure
- `tag:network-edge` - Edge routers (OPNsense, pve-vps)
- `tag:infra-services` - Infrastructure services
- `tag:client-stationary` - Always-on LAN devices
- `tag:client-roaming` - Mobile devices

**AutoApprovers** (enables automatic route approval):
```json
"autoApprovers": {
  "routes": {
    "10.0.0.0/24": ["tag:network-cloud", "tag:infra-services"],
    "192.168.x.0/24": ["tag:network-edge", "tag:network-homenet"]
  },
  "exitNode": ["tag:network-edge"]
}
```

**Grants** (access control):
- `infra-services` + `network-edge` → full access
- `client-stationary` → full access
- `network-homenet` ↔ `network-cloud` → bidirectional access

### Device Tags Applied

| Device | Tags |
|--------|------|
| pve-vps | infra-services, network-cloud, network-edge |
| opnsense | infra-services, network-edge, network-homenet |
| cachy-moto | client-stationary, network-homenet |

### Routing Fix Script

`tailscale-routing-fix.sh` manages the ip rules needed for LAN priority:

```bash
# Add rules before enabling accept-routes
sudo ./tailscale-routing-fix.sh add
sudo tailscale set --accept-routes

# Check status
./tailscale-routing-fix.sh status

# Remove rules
sudo ./tailscale-routing-fix.sh remove
```

## Verification

### Test Results

| Test | Expected | Actual |
|------|----------|--------|
| `traceroute 192.168.3.52` | via 10.0.2.1 (local) | ✅ via 10.0.2.1 |
| `ping 10.0.0.1` | via tailscale0 | ✅ ~12ms latency |
| `curl https://10.0.0.1:8006` | Proxmox UI | ✅ Returns HTML |

### Route Verification

```bash
# LAN traffic uses main table
$ ip route get 192.168.3.52
192.168.3.52 via 10.0.2.1 dev enp2s0f1np1 src 10.0.2.51

# Cloudenv traffic uses Tailscale
$ ip route get 10.0.0.1
10.0.0.1 dev tailscale0 table 52 src 100.86.4.17
```

## Files

- `proposed-acl.hjson` - Full ACL policy in HuJSON format
- `tailscale-routing-fix.sh` - Script to manage ip rules for LAN priority
- `spec.md` - Original feature specification

## Non-Tailscale Client Access

By default, non-Tailscale clients on the home LAN cannot reach the cloudenv subnet (10.0.0.0/24) even though OPNsense has `--accept-routes` enabled and the route exists in its routing table.

### Problem

When a LAN client sends traffic to 10.0.0.0/24:
1. Traffic arrives at OPNsense
2. OPNsense looks up route → tailscale0 interface
3. Traffic is forwarded with **original source IP** (e.g., 192.168.1.192)
4. Tailscale daemon doesn't encapsulate forwarded traffic from non-local sources

### Solution: Outbound NAT on Tailscale Interface

Configure OPNsense to NAT traffic destined for cloudenv so it appears to originate from OPNsense's Tailscale IP:

**OPNsense Configuration**:
1. **Firewall → NAT → Outbound**
2. Set mode to **Hybrid** (or Manual)
3. Add rule:
   - **Interface**: Tailscale
   - **Source**: Trusted_LAN net (or specific LAN networks)
   - **Destination**: 10.0.0.0/24
   - **Translation**: Interface Address
   - **Description**: "NAT LAN to CloudEnv via Tailscale"
4. Save and Apply

### Traffic Flow After NAT

```
LAN Client (192.168.1.192)
    │
    │ Packet to 10.0.0.1
    ▼
OPNsense LAN interface
    │
    │ NAT: src 192.168.1.192 → src 100.111.47.49
    ▼
OPNsense Tailscale (100.111.47.49)
    │
    │ Tailscale encapsulates (src is now local)
    ▼
pve-vps Tailscale (100.84.93.46)
    │
    │ Delivers to 10.0.0.1
    ▼
✅ Success - Reply returns via same path
```

### Verification

From a non-Tailscale LAN client:
```bash
# Should succeed after NAT rule is applied
ping 10.0.0.1
traceroute -n 10.0.0.1
```

## Notes

1. **pve-vps IP**: The VPS host has IP 10.0.0.1 on vmbr1 (not 10.0.0.10 as in original spec)
2. **Persistence**: The ip rules are not persistent across reboots. Use systemd service or NetworkManager dispatcher for persistence.
3. **OPNsense routes**: Home LAN subnets (192.168.x.x) are advertised by OPNsense, enabling remote access when not on LAN
4. **Non-Tailscale clients**: Require Outbound NAT on OPNsense's Tailscale interface to reach cloudenv (10.0.0.0/24)
