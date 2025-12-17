# Feature Specification: Core Infrastructure Setup

**Feature Branch**: `1-core-infrastructure`
**Created**: 2025-12-16
**Status**: Draft
**Input**: Deploy core infrastructure to SSDNodes VPS: OPNsense firewall capturing public IP, Proxmox VE on private network, VPN site-to-site connectivity to home network

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Secure Network Perimeter Establishment (Priority: P1)

As an infrastructure administrator, I want the VPS public IP to be exclusively controlled by a firewall appliance so that all traffic entering or leaving the environment passes through defined security controls.

**Definition of "Exclusively Controlled"**: OPNsense owns the WAN interface via macvtap bridge binding to the host's physical interface. No other process on the VPS host or any VM binds to the public IP address. All public IP traffic is captured by OPNsense's WAN interface at Layer 2.

**Why this priority**: Without the firewall controlling the public interface, no other infrastructure can be safely deployed. This is the foundational security boundary.

**Independent Test**: Can be fully tested by verifying the firewall owns the public IP, responds to allowed traffic (ICMP ping, VPN ports), and blocks all other inbound traffic. Delivers secure network perimeter.

**Acceptance Scenarios**:

1. **Given** a freshly provisioned SSDNodes VPS, **When** OPNsense is deployed and configured, **Then** the public IPv4 address responds only to explicitly permitted services (VPN, management) and all other inbound connections are blocked.
2. **Given** OPNsense controlling the WAN interface, **When** an internal private network is configured, **Then** a new virtual network segment exists for VMs with NAT egress through the firewall.
3. **Given** OPNsense is running, **When** firewall rules are reviewed, **Then** default-deny is enforced with explicit allow rules documented.

---

### User Story 2 - VPN Site-to-Site Connectivity (Priority: P2)

As an infrastructure administrator, I want a secure VPN tunnel between the VPS and my home network so that I can access resources on the VPS private network as if they were on my local LAN.

**Why this priority**: VPN connectivity is required before Proxmox can be practically managed, since Proxmox will have no direct public access.

**Independent Test**: Can be fully tested by establishing the VPN tunnel, then pinging or connecting to a service on the VPS private network from a device on the home network. Delivers seamless remote access.

**Acceptance Scenarios**:

1. **Given** OPNsense is configured with a private network, **When** the VPN tunnel is established to the home network, **Then** bidirectional traffic flows between home LAN and VPS private network.
2. **Given** a working VPN tunnel, **When** I access a service IP on the VPS private subnet from my home workstation, **Then** the connection succeeds without port forwarding or public exposure.
3. **Given** the VPN tunnel is active, **When** the tunnel is disrupted (network hiccup), **Then** it automatically reconnects without manual intervention.

---

### User Story 3 - Proxmox VE Deployment (Priority: P3)

As an infrastructure administrator, I want Proxmox VE running as a VM on the VPS so that I can create and manage additional virtual machines as if working with a local hypervisor.

**Why this priority**: Proxmox is the end-goal platform but depends on network infrastructure being in place first.

**Independent Test**: Can be fully tested by accessing the Proxmox web UI over VPN, creating a test VM, and verifying VM lifecycle operations work correctly. Delivers virtualization capability.

**Acceptance Scenarios**:

1. **Given** the VPS private network and VPN tunnel are operational, **When** Proxmox VE is deployed, **Then** the Proxmox web UI is accessible from home network via VPN at a private IP address.
2. **Given** Proxmox is accessible via VPN, **When** I create a new VM through the web interface, **Then** the VM is created, starts, and obtains network connectivity on the private subnet.
3. **Given** Proxmox is running, **When** I check resource allocation, **Then** sufficient vCPU, RAM, and storage are available for running production workloads.

---

### Edge Cases

- What happens if the VPS provider assigns a different public IP after reboot?
  - OPNsense WAN interface should obtain the new IP via DHCP and VPN tunnel should re-establish automatically.
- How does the system handle VPN tunnel failure during active sessions?
  - Active SSH/management sessions will drop; reconnection required after tunnel recovery.
- What happens if nested virtualization support is disabled on the VPS?
  - Proxmox can still run but with limited guest capabilities; QEMU/KVM performance may be reduced.
- How is initial access established before VPN is configured?
  - Temporary SSH access via public IP with firewall rules; removed after VPN is operational.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST deploy OPNsense as a virtual appliance that captures the VPS public IPv4 address on its WAN interface.
- **FR-002**: System MUST create a private virtual network segment (e.g., 10.0.0.0/24) isolated from the public interface.
- **FR-003**: System MUST configure OPNsense with default-deny firewall rules, allowing only explicitly defined services.
- **FR-004**: System MUST establish VPN connectivity by joining OPNsense to the existing Tailscale tailnet, enabling mesh access between VPS private network and home network.
- **FR-005**: System MUST deploy Proxmox VE as a VM on the private network with no direct public interface.
- **FR-006**: System MUST allocate sufficient resources to Proxmox for running nested VMs (minimum 8 vCPU, 48GB RAM, 800GB storage).
- **FR-007**: System MUST provide automated VPN tunnel reconnection on network disruption.
- **FR-008**: System MUST allow secure initial provisioning access before VPN is established (temporary SSH, later disabled).
- **FR-009**: System MUST implement credential rotation: Tailscale auth keys rotated every 90 days, Ansible Vault password rotated annually, and OPNsense API credentials rotated on personnel changes.

### Key Entities

- **OPNsense Firewall**: Virtual appliance controlling public IP, providing NAT, firewall, and VPN services. Owns WAN (public) and LAN (private) interfaces.
- **Private Network Segment**: Virtual network (e.g., 10.0.0.0/24) for internal VMs, NAT'd to internet through OPNsense.
- **Tailscale Tailnet**: Existing mesh VPN network; VPS OPNsense joins as a new node, gaining automatic connectivity to all tailnet devices including home network.
- **Proxmox VE Host**: Virtualization platform VM running on private network, hosting future workloads.
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

- SSDNodes VPS is provisioned with Ubuntu or Debian base OS capable of hosting virtualization.
- Nested virtualization (passthrough) is enabled on the VPS as specified at purchase.
- Home network runs OPNsense firewall already connected to an existing Tailscale tailnet.
- Tailscale account exists with active tailnet containing multiple devices.
- Private network subnet (10.0.0.0/24) does not conflict with home network addressing or existing tailnet routes.
- Administrator has SSH key pair for initial secure access.
- SSDNodes API access is available for any required automation.
