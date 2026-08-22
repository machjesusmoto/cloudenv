# CloudEnv Project Overview

## Purpose
Multi-feature infrastructure project for deploying secure cloud services on SSDNodes VPS.

## Current State
- **Feature 1**: ✅ Complete - Proxmox VE + Tailscale on SSDNodes VPS
- **Feature 2**: ✅ Complete - Tailscale ACL configuration with routing fixes

## Key Architecture
- **VPS Host**: Proxmox VE at 10.0.0.1 (vmbr1), Tailscale IP 100.84.93.46
- **Home Gateway**: OPNsense with Tailscale (100.111.47.49), advertises home LAN subnets
- **Subnet Routing**: 10.0.0.0/24 (cloudenv) ↔ home LANs via Tailscale

## Important Configuration Details

### Tailscale Routing on Linux Clients
- Use ip rules at priority 5200 to force LAN traffic through main table
- Script: `features/2-tailscale-acl-configuration/tailscale-routing-fix.sh`
- Systemd service: `tailscale-lan-routes.service`

### Non-Tailscale Client Access
- Requires Outbound NAT on OPNsense's Tailscale interface
- NAT LAN traffic to 10.0.0.0/24 so it appears from OPNsense's Tailscale IP
- Without NAT, Tailscale daemon won't encapsulate forwarded traffic

## Security Policy
- Public repository - no secrets, no public IPs
- Use placeholders: `<VPS_PUBLIC_IP>`, `<VPS_GATEWAY>`
- Tailscale IPs (100.x.x.x) and RFC1918 addresses are acceptable

## Workflow
Uses spec-kit for specification-driven development:
- `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` → `/speckit.implement`
