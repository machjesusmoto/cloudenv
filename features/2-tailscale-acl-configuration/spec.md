# Feature 2: Tailscale ACL Configuration

**Status**: ✅ Complete
**Created**: 2025-12-23
**Branch**: `2-tailscale-acl-configuration`

## Overview

Holistic review and reconfiguration of Tailscale ACLs (Access Control Lists) to align with current infrastructure goals, particularly supporting the cloudenv deployment and home network integration.

## Current State

### Tailnet Devices (as of 2025-12-23)
| Device | IP | Type | Status |
|--------|-----|------|--------|
| cachy-moto | 100.86.4.17 | linux | Active (workstation) |
| pve-vps | 100.84.93.46 | linux | Active (cloudenv Proxmox) |
| ds918-1 | 100.112.62.11 | linux | Active (Synology NAS) |
| pikvm | 100.64.245.51 | linux | Active |
| opnsense | 100.111.47.49 | freebsd | Idle (home firewall, exit node) |
| opnsense-1 | 100.98.189.61 | freebsd | Offline |
| azr01admin06 | 100.98.38.42 | windows | Active |
| + 6 other devices | - | various | Mixed |

### Known Issues
- `--accept-routes` is false on workstation (not accepting advertised routes)
- ACL configuration needs review for cloudenv integration
- Subnet routing configuration needs validation

## Goals

### Primary Objectives
1. **Review current ACL policy** - Document existing rules and their purpose
2. **Validate subnet routing** - Ensure 10.0.0.0/24 (cloudenv private network) is properly advertised and accessible
3. **Implement least-privilege access** - Tighten ACLs where appropriate
4. **Enable proper exit node configuration** - Configure opnsense as exit node for specific use cases
5. **Tag-based access control** - Implement logical grouping via tags

### Secondary Objectives
1. Document ACL policy for future reference
2. Set up ACL testing/validation procedures
3. Configure SSH access policies
4. Review and configure DNS settings

## User Stories

### US-2.1: ACL Visibility
**As a** network administrator
**I want to** view and understand all current Tailscale ACL rules
**So that** I can make informed decisions about access control

**Acceptance Criteria**:
- [x] Current ACL policy exported and documented (proposed-acl.hjson)
- [x] Each rule's purpose documented (SOLUTION.md)
- [x] Devices and their tags cataloged (see SOLUTION.md)

### US-2.2: Cloudenv Access
**As a** developer
**I want to** access cloudenv resources (Proxmox, VMs) via Tailscale
**So that** I can manage infrastructure without exposing it publicly

**Acceptance Criteria**:
- [x] 10.0.0.0/24 subnet accessible from authorized devices (via tailscale0)
- [x] Proxmox web UI (8006) accessible via Tailscale (https://10.0.0.1:8006)
- [x] SSH access to Proxmox and VMs working (via 100.84.93.46 or 10.0.0.1)
- [x] No public exposure of management interfaces

### US-2.3: Tag-Based Access Control
**As a** security-conscious administrator
**I want to** organize devices into logical groups via tags
**So that** I can apply granular access policies

**Acceptance Criteria**:
- [x] Devices categorized by function (client-stationary, client-roaming, infra-services)
- [x] ACL rules use tags instead of individual devices (grants use tags exclusively)
- [x] New devices can inherit permissions via tags (autoApprovers configured)

### US-2.4: Exit Node Configuration
**As a** a user
**I want to** route traffic through specific exit nodes
**So that** I can access geo-restricted resources or improve privacy

**Acceptance Criteria**:
- [x] opnsense configured as exit node (offers exit node in tailscale status)
- [x] Exit node usage controllable per-device (via Tailscale app/CLI)
- [x] Documentation for using exit nodes (see SOLUTION.md)

## Technical Requirements

### MCP Integration
- Tailscale MCP server for direct API access
- Query capabilities: devices, ACLs, routes, DNS
- Mutation capabilities: ACL updates, device management

### ACL Structure
```json
{
  "groups": {},
  "tagOwners": {},
  "acls": [],
  "ssh": [],
  "autoApprovers": {},
  "tests": []
}
```

### Security Considerations
- No wildcard allow rules
- Explicit deny for sensitive ports
- SSH access limited to specific devices/tags
- Regular ACL audit schedule

## Dependencies

- Tailscale MCP server (`/home/dtaylor/go/bin/tailscale-mcp-server`)
- Tailscale API key (configured)
- Feature 1 complete (cloudenv infrastructure deployed)

## Out of Scope

- Tailscale Funnel configuration (future feature)
- MagicDNS custom domains
- DERP server configuration
