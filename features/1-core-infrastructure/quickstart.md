# Quickstart: Core Infrastructure Setup

**Feature**: 1-core-infrastructure
**Date**: 2025-12-23
**Status**: Deployed and Operational

## Architecture Overview

```
Internet ──► SSDNodes Provider Firewall ──► Proxmox VE Host (172.93.48.55)
                                                    │
                                                    ├── vmbr0 (public: 172.93.48.55/24)
                                                    ├── vmbr1 (private: 10.0.0.1/24)
                                                    ├── Tailscale (100.84.93.46)
                                                    │       └── advertises 10.0.0.0/24
                                                    └── Future VMs on vmbr1

Home Network ──► Tailscale ──► pve-vps (100.84.93.46) ──► 10.0.0.0/24
```

## Prerequisites

### Account Requirements

- [x] SSDNodes VPS provisioned (12 vCPU, 64GB RAM, 1200GB NVMe)
- [x] SSDNodes VPS has Debian 13 (Trixie) installed
- [x] SSDNodes Provider Firewall addon enabled
- [x] Tailscale account with existing tailnet
- [x] SSH key pair for authentication

### Network Requirements

- [x] Private subnet `10.0.0.0/24` doesn't conflict with home network
- [x] Tailscale ACLs allow subnet routing

## Deployed Configuration

### VPS Details

| Property | Value |
|----------|-------|
| Provider | SSDNodes |
| Public IP | 172.93.48.55 |
| Hostname | pve.vps.local |
| OS | Debian 13 (Trixie) |
| Proxmox | 9.1.2 |
| Kernel | 6.8.12-17-pve |

### Network Configuration

| Interface | IP Address | Purpose |
|-----------|------------|---------|
| vmbr0 | 172.93.48.55/24 | Public bridge (WAN) |
| vmbr1 | 10.0.0.1/24 | Private bridge (LAN for VMs) |
| tailscale0 | 100.84.93.46 | Tailscale VPN |

### Access Methods

| Method | URL/Command | Notes |
|--------|-------------|-------|
| Proxmox Web UI | https://100.84.93.46:8006 | Via Tailscale (recommended) |
| SSH via Tailscale | `ssh root@100.84.93.46` | Secure access |
| SSH via Public IP | `ssh root@172.93.48.55` | Requires provider firewall allow |

## Deployment Steps (What Was Done)

### Phase 1: Initial VPS Setup

```bash
# SSH to VPS (provider firewall must allow your IP)
ssh root@172.93.48.55

# Configure hostname
hostnamectl set-hostname pve.vps.local
echo "127.0.1.1 pve.vps.local pve" >> /etc/hosts

# Disable password authentication
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd
```

### Phase 2: Install Proxmox VE 9

```bash
# Add Proxmox VE 9 repository (Debian 13/Trixie)
curl -fsSL https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg \
    -o /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg

echo "deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
    > /etc/apt/sources.list.d/pve-no-subscription.list

# Install Proxmox VE
apt-get update
apt-get install -y proxmox-ve postfix open-iscsi chrony

# Disable enterprise repo (no subscription)
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
```

### Phase 3: Configure Routed Networking

```bash
# Edit /etc/network/interfaces
cat > /etc/network/interfaces << 'EOF'
auto lo
iface lo inet loopback

iface enp3s0 inet manual

auto vmbr0
iface vmbr0 inet static
    address 172.93.48.55/24
    gateway 172.93.48.1
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
EOF

# Configure GRUB to boot Proxmox kernel
sed -i 's/^GRUB_DEFAULT=.*/GRUB_DEFAULT="1>2"/' /etc/default/grub
update-grub

# Reboot to apply
reboot
```

### Phase 4: Install Tailscale

```bash
# Add Tailscale repository
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.noarmor.gpg \
    | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/debian/trixie.tailscale-keyring.list \
    | tee /etc/apt/sources.list.d/tailscale.list

# Install and start
apt-get update
apt-get install -y tailscale

# Configure IP forwarding for Tailscale
cat > /etc/sysctl.d/99-tailscale.conf << 'EOF'
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf

# Authenticate and advertise subnet
tailscale up --advertise-routes=10.0.0.0/24 --accept-routes --hostname=pve-vps
```

### Phase 5: Configure Provider Firewall

In SSDNodes portal, configure firewall rules:

| Rule | Action | Protocol | Port | Source | Description |
|------|--------|----------|------|--------|-------------|
| 1 | Allow | TCP | 22 | Admin IP | SSH access |
| 2 | Allow | ICMP | - | Any | Ping monitoring |
| 3 | Deny | All | All | Any | Default deny |

### Phase 6: Approve Tailscale Subnet Route

1. Go to https://login.tailscale.com/admin/machines
2. Find `pve-vps`
3. Click "..." → "Edit route settings"
4. Enable `10.0.0.0/24` subnet route
5. Save

## Validation Checklist

```bash
# Run from local machine with Tailscale
# 1. Tailscale direct access
ping -c 2 100.84.93.46

# 2. Proxmox Web UI
curl -sk https://100.84.93.46:8006 | head -c 100

# 3. SSH via Tailscale
ssh root@100.84.93.46 'pveversion'

# 4. Subnet route (if enabled on your client)
ping -c 2 10.0.0.1
```

## Creating VMs

VMs should be created on the `vmbr1` bridge:

1. Access Proxmox UI: https://100.84.93.46:8006
2. Create VM with network on `vmbr1`
3. Configure VM with:
   - IP: 10.0.0.x/24 (pick from DHCP range 100-199 or static 2-49)
   - Gateway: 10.0.0.1
   - DNS: 10.0.0.1 or external (1.1.1.1)

VMs will have:
- NAT internet access via Proxmox host
- Access from tailnet via subnet route (if approved)

## Troubleshooting

### Cannot Access Proxmox UI

```bash
# Verify Tailscale is connected
tailscale status | grep pve-vps

# Test direct connection
ping 100.84.93.46

# Test HTTPS
curl -sk https://100.84.93.46:8006
```

### Subnet Route Not Working

1. Verify route is approved in Tailscale admin
2. Enable route acceptance on client: `tailscale up --accept-routes`
3. Check for conflicting local routes: `ip route | grep 10.0.0`
4. Check Tailscale ACLs for route restrictions

### SSH Connection Issues

```bash
# If locked out, use SSDNodes console or
# ensure provider firewall allows your IP on port 22
ssh -v root@172.93.48.55
```

## Maintenance

### Update Proxmox

```bash
ssh root@100.84.93.46
apt-get update && apt-get dist-upgrade
```

### Rotate Tailscale Auth Key

```bash
# Generate new key in Tailscale admin console
# Then on VPS:
tailscale logout
tailscale up --advertise-routes=10.0.0.0/24 --accept-routes --hostname=pve-vps
```

### Backup Configuration

```bash
# From local machine
ssh root@100.84.93.46 'tar czf - /etc/network/interfaces /etc/pve /etc/tailscale' \
    > proxmox-backup-$(date +%Y%m%d).tar.gz
```

## Security Notes

- SSH password authentication is disabled
- Provider firewall blocks all except SSH from admin IP
- Proxmox UI only accessible via Tailscale (no public exposure)
- VMs isolated on private network with NAT egress
- Tailscale provides encrypted overlay for all management traffic
