# Feature Specification: Core Infrastructure Setup

**Feature Branch**: `1-core-infrastructure`
**Created**: 2025-12-16
**Updated**: 2025-12-23
**Status**: ✅ Complete
**Input**: Deploy core infrastructure to SSDNodes VPS: Proxmox VE as host OS with routed networking, Tailscale VPN directly on host, SSDNodes provider firewall for edge protection

## Completion Summary

**Deployed**: 2025-12-23
**Architecture**: Simplified (Proxmox VE direct on host, no OPNsense VM)
**Validation**: All acceptance criteria met, Proxmox accessible via Tailscale

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Network Perimeter Establishment (Priority: P1)

As an infrastructure administrator, I want a layered security architecture with edge protection and internal segmentation so that all traffic entering or leaving the environment passes through defined security controls.

**Definition of "Layered Security"**: SSDNodes provider firewall handles edge protection (public IP filtering), while Proxmox's built-in firewall provides internal VM segmentation. Tailscale runs directly on the Proxmox host as a subnet router, advertising the private network to the home tailnet.

**Why this priority**: Without the provider firewall controlling inbound access and internal segmentation, no other infrastructure can be safely deployed. This is the foundational security boundary.

**Independent Test**: Can be fully tested by verifying the provider firewall blocks unauthorized traffic, Proxmox is accessible only via SSH with key auth, and internal VMs have NAT egress through Proxmox host. Delivers secure network perimeter.

**Acceptance Scenarios**:

1. **Given** a freshly provisioned SSDNodes VPS with provider firewall, **When** Proxmox VE is installed and configured, **Then** the public IPv4 address responds only to explicitly permitted services (SSH from admin IP) and all other inbound connections are blocked by the provider firewall.
2. **Given** Proxmox with routed networking, **When** an internal private network is configured, **Then** a new virtual network segment exists for VMs with NAT egress through the Proxmox host.
3. **Given** the security architecture is deployed, **When** firewall rules are reviewed, **Then** default-deny is enforced at both the provider level and Proxmox firewall level with explicit allow rules documented.

---

### User Story 2 - VPN Site-to-Site Connectivity (Priority: P2)

As an infrastructure administrator, I want a secure VPN tunnel between the VPS and my home network so that I can access resources on the VPS private network as if they were on my local LAN.

**Why this priority**: VPN connectivity is required before Proxmox can be practically managed, since Proxmox will have no direct public access.

**Independent Test**: Can be fully tested by establishing the VPN tunnel, then pinging or connecting to a service on the VPS private network from a device on the home network. Delivers seamless remote access.

**Acceptance Scenarios**:

1. **Given** Proxmox is configured with a private network bridge, **When** Tailscale is running as subnet router, **Then** bidirectional traffic flows between home LAN and VPS private network.
2. **Given** a working VPN tunnel, **When** I access a service IP on the VPS private subnet from my home workstation, **Then** the connection succeeds without port forwarding or public exposure.
3. **Given** the VPN tunnel is active, **When** the tunnel is disrupted (network hiccup), **Then** it automatically reconnects without manual intervention.

---

### User Story 3 - Proxmox VE Host Platform (Priority: P0 - Prerequisite)

As an infrastructure administrator, I want Proxmox VE installed directly on the VPS host OS so that I have a bare-metal hypervisor with maximum performance and full resource availability.

**Why this priority**: Proxmox as the host OS is the foundation for all other VMs. It must be deployed first before OPNsense or any other infrastructure.

**Independent Test**: Can be fully tested by accessing the Proxmox web UI via SSH tunnel or directly (with provider firewall allowing), verifying KVM/QEMU is functional, and creating a test VM. Delivers virtualization capability.

**Acceptance Scenarios**:

1. **Given** a freshly provisioned SSDNodes VPS with Debian 13, **When** Proxmox VE is installed, **Then** the Proxmox web UI is accessible via SSH tunnel or directly from allowed IPs.
2. **Given** Proxmox is installed with routed networking, **When** I create a new VM through the web interface, **Then** the VM is created, starts, and obtains network connectivity on the private subnet (10.0.0.0/24).
3. **Given** Proxmox is running, **When** I check resource allocation, **Then** the full VPS resources (12 vCPU, 64GB RAM, 1200GB NVMe) are available for running workloads.

---

### Edge Cases

- What happens if the VPS provider assigns a different public IP after reboot?
  - Proxmox host will obtain new IP via DHCP. Provider firewall rules and Tailscale will re-establish automatically.
- How does the system handle VPN tunnel failure during active sessions?
  - Active SSH/management sessions via Tailscale will drop; reconnection required after tunnel recovery. Direct SSH to Proxmox (if enabled) remains available.
- What happens if the provider firewall is misconfigured?
  - Fallback to Proxmox built-in firewall for VM protection. Proxmox host may lose SSH access until provider firewall is corrected via SSDNodes API/portal.
- How is initial access established before VPN is configured?
  - SSH access via public IP with provider firewall allowing port 22 from admin IP only. Tailscale configured on Proxmox host for long-term access.
- What if SSDNodes API is unavailable?
  - Provider firewall can be managed via web portal as fallback. Initial deployment doesn't require API.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST install Proxmox VE directly on the Debian 13 host OS with routed networking configuration.
- **FR-002**: System MUST configure a private virtual network segment (10.0.0.0/24) via Proxmox bridge (vmbr1) for VM traffic.
- **FR-003**: System MUST configure SSDNodes provider firewall with default-deny, allowing only SSH (port 22) from admin IP and ICMP.
- **FR-004**: System MUST configure NAT on Proxmox host for private network (10.0.0.0/24) internet egress.
- **FR-005**: System MUST establish VPN connectivity by running Tailscale on Proxmox host, advertising the 10.0.0.0/24 subnet to the existing tailnet.
- **FR-006**: System MUST configure SSH key-based authentication on Proxmox host, disabling password authentication.
- **FR-007**: System MUST provide automated VPN tunnel reconnection on network disruption.
- **FR-008**: System MUST enable Proxmox web UI access via Tailscale (port 8006) after VPN is established.
- **FR-009**: System MUST implement credential rotation: Tailscale auth keys rotated every 90 days, SSH keys rotated annually.

### Key Entities

- **Proxmox VE Host**: Virtualization platform installed directly on Debian 13 host. Manages VMs via KVM/QEMU, provides routed networking via vmbr0 (WAN) and vmbr1 (LAN) bridges. Also runs Tailscale as subnet router and provides NAT for VMs.
- **SSDNodes Provider Firewall**: Cloud-level firewall managed via API/portal. Handles edge protection, controls inbound traffic to public IP before it reaches the host.
- **Private Network Segment**: Virtual network (10.0.0.0/24) on vmbr1 for internal VMs, NAT'd to internet through Proxmox host.
- **Tailscale Tailnet**: Existing mesh VPN network; Proxmox host joins as a subnet router, advertising 10.0.0.0/24 for seamless home network access.
- **Home OPNsense**: Existing home network firewall already connected to the tailnet; serves as the access point to VPS resources.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: From any device on the home network, private services on the VPS respond within 100ms round-trip time (accounting for Seattle geographic location).
- **SC-002**: VPN tunnel achieves 99% uptime over a 7-day observation period (automatic reconnection handles transient failures).
- **SC-003**: Unauthorized connection attempts to VPS public IP are blocked and logged with zero successful intrusions.
- **SC-004**: Administrator can create, start, stop, and delete a VM on Proxmox within 5 minutes via web UI accessed over VPN.
- **SC-005**: Total deployment from bare VPS to fully operational infrastructure completes within 4 hours (including initial configuration).
- **SC-006**: Configuration backup allows complete infrastructure recreation within 2 hours from documented procedure.

## Assumptions

- SSDNodes VPS is provisioned with Debian 13 (Trixie) base OS.
- SSDNodes provider firewall addon is enabled and API access is available.
- KVM/QEMU virtualization is supported on the VPS hardware.
- Home network runs OPNsense firewall already connected to an existing Tailscale tailnet.
- Tailscale account exists with active tailnet containing multiple devices.
- Private network subnet (10.0.0.0/24) does not conflict with home network addressing or existing tailnet routes.
- Administrator has SSH key pair for initial secure access (stored in 1Password).
- VPS public IP is 172.93.48.55 (or obtained via DHCP if changed).
