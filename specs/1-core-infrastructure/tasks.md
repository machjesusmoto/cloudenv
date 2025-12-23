# Tasks: Core Infrastructure Setup

**Status**: ✅ COMPLETE (2025-12-23)
**Input**: Design documents from `/specs/1-core-infrastructure/`
**Deployment**: Manual with documentation (see `quickstart.md`)

## Actual Deployment Summary

The original plan included Ansible automation and OPNsense VM. The actual deployment was simplified:

- **Architecture**: Proxmox VE directly on Debian 13 host
- **VPN**: Tailscale on Proxmox host (not in VM)
- **Edge Protection**: SSDNodes provider firewall
- **Documentation**: Complete step-by-step guide in `quickstart.md`

---

## Phase 1: Initial VPS Setup ✅

| Task | Description | Status |
|------|-------------|--------|
| T001 | SSH to VPS via public IP | ✅ Complete |
| T002 | Configure hostname (`pve.vps.local`) | ✅ Complete |
| T003 | Update `/etc/hosts` with hostname | ✅ Complete |
| T004 | Disable SSH password authentication | ✅ Complete |
| T005 | Restart SSH service | ✅ Complete |

**Validation**: SSH key auth working, hostname set

---

## Phase 2: Install Proxmox VE 9 ✅

| Task | Description | Status |
|------|-------------|--------|
| T006 | Add Proxmox VE 9 repository GPG key | ✅ Complete |
| T007 | Add pve-no-subscription repository | ✅ Complete |
| T008 | Run apt-get update | ✅ Complete |
| T009 | Install proxmox-ve, postfix, open-iscsi, chrony | ✅ Complete |
| T010 | Disable enterprise repository (no subscription) | ✅ Complete |

**Validation**: Proxmox VE 9.1.2 installed, `pveversion` returns version

---

## Phase 3: Configure Routed Networking ✅

| Task | Description | Status |
|------|-------------|--------|
| T011 | Create `/etc/network/interfaces` with vmbr0 (public) | ✅ Complete |
| T012 | Add vmbr1 (private 10.0.0.0/24) with NAT rules | ✅ Complete |
| T013 | Configure IP forwarding in vmbr1 post-up | ✅ Complete |
| T014 | Configure GRUB for Proxmox kernel (GRUB_DEFAULT="1>2") | ✅ Complete |
| T015 | Run update-grub | ✅ Complete |
| T016 | Reboot to apply network config and kernel | ✅ Complete |

**Validation**:
- vmbr0: 172.93.48.55/24 (public)
- vmbr1: 10.0.0.1/24 (private)
- Kernel: 6.8.12-17-pve

---

## Phase 4: Install Tailscale ✅

| Task | Description | Status |
|------|-------------|--------|
| T017 | Add Tailscale repository GPG key | ✅ Complete |
| T018 | Add Tailscale apt repository | ✅ Complete |
| T019 | Install tailscale package | ✅ Complete |
| T020 | Configure IP forwarding for Tailscale | ✅ Complete |
| T021 | Run `tailscale up --advertise-routes=10.0.0.0/24` | ✅ Complete |
| T022 | Authenticate via browser URL | ✅ Complete |

**Validation**: Tailscale connected, advertising 10.0.0.0/24

---

## Phase 5: Configure Provider Firewall ✅

| Task | Description | Status |
|------|-------------|--------|
| T023 | Log in to SSDNodes portal | ✅ Complete |
| T024 | Enable firewall addon | ✅ Complete |
| T025 | Add rule: Allow TCP 22 from admin IP | ✅ Complete |
| T026 | Add rule: Allow ICMP from any | ✅ Complete |
| T027 | Set default deny for all other traffic | ✅ Complete |

**Validation**: Only SSH (22) and ICMP accessible from internet

---

## Phase 6: Approve Tailscale Subnet Route ✅

| Task | Description | Status |
|------|-------------|--------|
| T028 | Go to Tailscale admin console | ✅ Complete |
| T029 | Find `pve-vps` machine | ✅ Complete |
| T030 | Edit route settings | ✅ Complete |
| T031 | Enable 10.0.0.0/24 subnet route | ✅ Complete |
| T032 | Save changes | ✅ Complete |

**Validation**: Subnet route approved and advertised

---

## Final Validation ✅

| Check | Command | Result |
|-------|---------|--------|
| Tailscale access | `ping 100.84.93.46` | ✅ Pass |
| Proxmox Web UI | `curl -sk https://100.84.93.46:8006` | ✅ Pass |
| SSH via Tailscale | `ssh root@100.84.93.46 'pveversion'` | ✅ Pass |
| Subnet route | `ping 10.0.0.1` | ⚠️ Client-dependent |

---

## Deployed Infrastructure

| Component | Value |
|-----------|-------|
| Public IP | 172.93.48.55 |
| Tailscale IP | 100.84.93.46 |
| Private Gateway | 10.0.0.1 |
| Proxmox Version | 9.1.2 |
| Kernel | 6.8.12-17-pve |
| Tailscale Version | 1.92.3 |

---

## Notes

1. **Simplified Architecture**: Original plan included OPNsense VM and Ansible automation. Actual deployment is simpler and more efficient.

2. **Documentation-Driven**: All steps documented in `quickstart.md` for reproducibility.

3. **Subnet Route Note**: Subnet route (10.0.0.0/24) requires client-side configuration:
   - Client must run `tailscale up --accept-routes`
   - Tailscale ACLs must allow subnet access

4. **Future Automation**: If needed, the documented steps can be converted to Ansible playbooks for automation.
