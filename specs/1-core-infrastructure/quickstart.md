# Quickstart: Core Infrastructure Setup

**Feature**: 1-core-infrastructure
**Date**: 2025-12-16

## Prerequisites

Before starting deployment, ensure you have:

### Local Machine Requirements

- [ ] Terraform >= 1.5.0 installed
- [ ] Ansible >= 2.15.0 installed
- [ ] SSH key pair generated (`~/.ssh/id_ed25519` or similar)
- [ ] Git configured for commits

### Account Requirements

- [ ] SSDNodes VPS provisioned (12 vCPU, 64GB RAM, 1200GB NVMe)
- [ ] SSDNodes VPS has Ubuntu 22.04 LTS installed
- [ ] SSDNodes VPS public IP noted
- [ ] Tailscale account with existing tailnet
- [ ] Tailscale auth key generated (reusable, with subnet router tag)

### Network Requirements

- [ ] Home OPNsense has Tailscale connected to tailnet
- [ ] Private subnet `10.0.0.0/24` doesn't conflict with home network
- [ ] Tailscale ACLs allow subnet routing from new node

## Quick Deploy (TL;DR)

```bash
# 1. Clone and configure
git clone <repo-url> cloudenv && cd cloudenv
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cp ansible/inventory/group_vars/vault.yml.example ansible/inventory/group_vars/vault.yml

# 2. Edit configuration
$EDITOR terraform/terraform.tfvars      # Set VPS IP, SSH key path
ansible-vault edit ansible/inventory/group_vars/vault.yml  # Set secrets

# 3. Deploy
./scripts/deploy.sh

# 4. Approve Tailscale subnet routes (in Tailscale admin console)

# 5. Verify
./scripts/test.sh
```

## Step-by-Step Deployment

### Step 1: Clone Repository

```bash
git clone <repo-url> cloudenv
cd cloudenv
```

### Step 2: Configure Terraform Variables

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars`:

```hcl
# VPS Connection
vps_host     = "203.0.113.10"  # Your SSDNodes public IP
ssh_key_path = "~/.ssh/id_ed25519"
ssh_user     = "root"          # Initial root access

# Network Configuration
private_network_cidr = "10.0.0.0/24"
opnsense_lan_ip      = "10.0.0.1"
proxmox_ip           = "10.0.0.10"

# Resource Allocation
opnsense_vcpus    = 2
opnsense_memory   = 4096
proxmox_vcpus     = 8
proxmox_memory    = 49152
proxmox_disk_size = 800
```

### Step 3: Configure Ansible Secrets

```bash
# Create vault password file (DO NOT commit this)
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass

# Create encrypted secrets
cp ansible/inventory/group_vars/vault.yml.example ansible/inventory/group_vars/vault.yml
ansible-vault edit ansible/inventory/group_vars/vault.yml
```

Edit vault.yml (inside encrypted file):

```yaml
# Tailscale
vault_tailscale_auth_key: "tskey-auth-xxxxx"

# OPNsense
vault_opnsense_root_password: "secure-generated-password"
vault_opnsense_api_key: ""      # Generated after install
vault_opnsense_api_secret: ""   # Generated after install

# Proxmox
vault_proxmox_root_password: "secure-generated-password"
```

### Step 4: Initialize Terraform

```bash
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
```

Review the plan, then apply:

```bash
terraform apply tfplan
```

### Step 5: Bootstrap VPS Host

```bash
cd ../ansible
ansible-playbook playbooks/bootstrap.yml -i inventory/hosts.yml
```

This installs:
- KVM/QEMU with libvirt
- Required dependencies
- SSH hardening (key-only auth)

### Step 6: Deploy OPNsense VM

```bash
ansible-playbook playbooks/opnsense.yml -i inventory/hosts.yml
```

This:
- Creates OPNsense VM with WAN/LAN interfaces
- Boots OPNsense and waits for SSH
- Applies initial firewall configuration
- Installs and configures Tailscale

### Step 7: Approve Tailscale Subnet Routes (Manual Action Required)

> **Why This Step?** Tailscale requires explicit admin approval for subnet routes as a security measure. The OPNsense device will advertise the `10.0.0.0/24` route, but it won't be active until you approve it in the admin console.

**Step 7.1: Open Tailscale Admin Console**

Navigate to: [https://login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)

**Step 7.2: Locate Your OPNsense Device**

Find the device named `opnsense-vps` (or your configured `tailscale_hostname`). It should show:
- Status: **Connected** (green dot)
- Subnets: **10.0.0.0/24** (pending approval - yellow warning)

If the device doesn't appear:
1. Wait 2-3 minutes for registration
2. Verify Tailscale is running: `tailscale status` on OPNsense
3. Check auth key validity in Tailscale admin under "Settings" → "Keys"

**Step 7.3: Approve Subnet Routes**

1. Click the **"..."** menu next to `opnsense-vps`
2. Select **"Edit route settings..."**
3. You'll see the advertised routes section showing `10.0.0.0/24`
4. Toggle the switch to **enable/approve** the route
5. Click **"Save"**

**Step 7.4: Verify Route Activation**

The device entry should now show:
- Subnets: **10.0.0.0/24** (approved - no warning)

From your home device (must be on same tailnet):

```bash
# Verify routes are visible
tailscale status

# Test connectivity to OPNsense LAN
ping 10.0.0.1

# Expected: successful ping responses
```

**Step 7.5: (Optional) Exit Node Configuration**

If you configured OPNsense as an exit node (`tailscale_exit_node: true`):

1. In the same "Edit route settings" dialog
2. Enable **"Use as exit node"** toggle
3. Click **"Save"**

To use the exit node from a client device:

```bash
tailscale up --exit-node=opnsense-vps
```

**Troubleshooting Route Approval**

| Issue | Solution |
|-------|----------|
| Device not appearing | Wait 2-3 min, check `tailscale status`, verify auth key |
| Routes not showing | Verify `--advertise-routes` is set, check OPNsense logs |
| Route approved but no connectivity | Check OPNsense firewall allows Tailscale interface traffic |
| "Subnet router not approved" warning | Complete Step 7.3 above |

**Security Note**: Once routes are approved, any device on your tailnet can reach the `10.0.0.0/24` network. Use Tailscale ACLs to restrict access if needed.

### Step 8: Deploy Proxmox VM

```bash
ansible-playbook playbooks/proxmox.yml -i inventory/hosts.yml
```

This:
- Creates Proxmox VM on private network
- Installs Proxmox VE from ISO
- Configures storage pools
- Sets up networking

### Step 9: Verify Deployment

```bash
./scripts/test.sh
```

Expected output:

```
[PASS] OPNsense WAN interface has public IP
[PASS] OPNsense LAN interface is 10.0.0.1
[PASS] Tailscale connected and advertising 10.0.0.0/24
[PASS] Proxmox reachable at 10.0.0.10:8006 via Tailscale
[PASS] Firewall default-deny verified
[PASS] No unauthorized ports exposed on public IP

All tests passed!
```

### Step 10: Access Proxmox

From any device on your home tailnet:

```bash
# Via browser
open https://10.0.0.10:8006

# Via SSH
ssh root@10.0.0.10
```

## Post-Deployment Tasks

### Run Full Validation Suite

```bash
# Quick smoke tests
./scripts/test.sh --quick

# Full test suite (from home via Tailscale)
./scripts/test.sh --from-tailnet

# Specific test types
./scripts/test.sh security        # Firewall rule validation
./scripts/test.sh connectivity    # Tailscale route tests
./scripts/test.sh proxmox         # Proxmox accessibility
```

### Disable Temporary SSH Access

After Tailscale is operational and **verified working**, remove initial SSH access:

```bash
# Safety check: Verify Tailscale connectivity first
tailscale ping opnsense-vps
ssh root@10.0.0.1  # via Tailscale

# Then harden
ansible-playbook playbooks/harden.yml -i inventory/hosts.yml --tags disable-direct-ssh
```

**Warning**: Do not run harden.yml until you have verified Tailscale connectivity!

### Create Backup

```bash
# Basic backup
./scripts/backup.sh

# Compressed and encrypted
./scripts/backup.sh --compress --encrypt

# Copy to remote host
./scripts/backup.sh --compress --remote backup-server.local

# Backup specific component
./scripts/backup.sh terraform   # Terraform state only
./scripts/backup.sh opnsense    # OPNsense config only
```

This creates:
- OPNsense configuration XML export
- Terraform state backup
- Ansible inventory and configuration
- Proxmox configuration files (if accessible)

### Update OPNsense

```bash
ansible-playbook playbooks/opnsense.yml -i inventory/hosts.yml --tags update
```

### Credential Rotation

Rotate credentials periodically for security:

```bash
# Interactive credential rotation
ansible-playbook playbooks/rotate-credentials.yml

# Rotate specific credentials
ansible-playbook playbooks/rotate-credentials.yml --tags tailscale
ansible-playbook playbooks/rotate-credentials.yml --tags vault
ansible-playbook playbooks/rotate-credentials.yml --tags ssh-keys

# View rotation schedule
ansible-playbook playbooks/rotate-credentials.yml --tags schedule
```

Recommended rotation schedule:
- Tailscale auth key: Every 90 days
- Ansible vault password: Every 180 days
- SSH keys: Every 365 days

## Troubleshooting

### Cannot SSH to VPS

1. Verify VPS is running in SSDNodes console
2. Check public IP is correct in terraform.tfvars
3. Verify SSH key is correct

```bash
ssh -i ~/.ssh/id_ed25519 root@<vps-ip> -v
```

### Tailscale Not Connecting

1. Verify auth key is valid and not expired
2. Check OPNsense has internet access
3. Review Tailscale logs on OPNsense

```bash
# On OPNsense
tailscale status
tailscale netcheck
```

### Cannot Reach Proxmox via Tailscale

1. Verify subnet routes are approved in Tailscale admin
2. Check OPNsense is advertising routes
3. Verify Proxmox has correct gateway (10.0.0.1)

```bash
# From home machine
tailscale status
ping 10.0.0.10
```

### Proxmox Web UI Not Loading

1. Verify Proxmox is running
2. Check port 8006 is open in OPNsense Tailscale rules
3. Try direct Tailscale IP if DNS issues

```bash
# Check from OPNsense
nc -zv 10.0.0.10 8006
```

## Destroy Infrastructure

To completely tear down:

```bash
./scripts/destroy.sh
```

This will:
1. Delete VMs
2. Remove storage volumes
3. Clean up network definitions
4. Preserve Terraform state for audit

**Warning**: This is destructive. Ensure backups exist.

## Disaster Recovery

In case of infrastructure failure, see the comprehensive disaster recovery runbook:

```bash
# Location
docs/disaster-recovery-runbook.md

# Quick reference for common scenarios:
# - OPNsense VM failure: RTO 30 min
# - Proxmox VM failure: RTO 45 min
# - VPS total loss: RTO 2 hours
# - Tailscale disconnected: RTO 10 min
```

For immediate recovery:

```bash
# Full infrastructure redeploy
./scripts/deploy.sh deploy

# Restore from backup
./scripts/backup.sh  # First, list available backups
# Then follow docs/disaster-recovery-runbook.md
```

## Next Steps

After successful deployment:

1. **Verify all tests pass**: `./scripts/test.sh all --from-tailnet`
2. **Create VMs on Proxmox**: Use web UI or Terraform provider
3. **Configure additional firewall rules**: Add services as needed
4. **Set up monitoring**: Consider adding Prometheus/Grafana
5. **Schedule regular backups**: `./scripts/backup.sh --compress`
6. **Review disaster recovery**: Read `docs/disaster-recovery-runbook.md`
7. **Document changes**: Update this repo with any modifications
