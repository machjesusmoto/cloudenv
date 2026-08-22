# CloudEnv Disaster Recovery Runbook

**T072: Disaster Recovery Documentation**
**Constitution II: Reliability Through Simplicity**
**Target RTO**: < 2 hours (SC-006)

---

## Quick Reference

| Scenario | RTO | Procedure |
|----------|-----|-----------|
| OPNsense VM failure | 30 min | [Rebuild OPNsense](#opnsense-recovery) |
| Proxmox VM failure | 45 min | [Rebuild Proxmox](#proxmox-recovery) |
| VPS total loss | 2 hours | [Full Recovery](#full-infrastructure-recovery) |
| Tailscale disconnected | 10 min | [Reconnect VPN](#tailscale-recovery) |
| Config corruption | 15 min | [Restore from backup](#restore-from-backup) |

---

## Prerequisites

### Required Access
- [ ] SSDNodes dashboard credentials
- [ ] Tailscale admin console access
- [ ] Ansible vault password
- [ ] SSH private key (`~/.ssh/cloudenv_key`)
- [ ] Recent backup (`./scripts/backup.sh`)

### Local Tools
```bash
# Verify tools are installed
terraform version    # >= 1.5.0
ansible --version    # >= 2.15
tailscale version    # Latest
ssh -V              # OpenSSH
```

---

## Emergency Contacts

| Resource | Access |
|----------|--------|
| SSDNodes Support | https://my.ssdnodes.com/support |
| Tailscale Admin | https://login.tailscale.com/admin |
| Backup Location | `./backups/` or remote host |

---

## Disaster Recovery Procedures

### OPNsense Recovery

**Scenario**: OPNsense VM is unresponsive or corrupted

**RTO**: 30 minutes

#### Step 1: Assess the Situation
```bash
# Check VM status from VPS console (SSDNodes dashboard)
# Or if VPS is accessible:
ssh root@<vps-public-ip> "virsh list --all"
```

#### Step 2: Attempt VM Restart
```bash
# Via VPS SSH (if accessible)
virsh destroy opnsense
virsh start opnsense

# Wait 60 seconds for boot
sleep 60

# Check if responding
ping -c 3 10.0.0.1
```

#### Step 3: Rebuild VM (if restart fails)
```bash
# Destroy corrupted VM
cd terraform
terraform destroy -target=module.opnsense

# Rebuild OPNsense
terraform apply -target=module.opnsense

# Reconfigure
cd ../ansible
ansible-playbook playbooks/opnsense.yml
ansible-playbook playbooks/tailscale.yml

# Approve Tailscale routes
echo "ACTION: Approve subnet routes at https://login.tailscale.com/admin/machines"
```

#### Step 4: Restore Configuration (if backup available)
```bash
# Find latest backup
ls -la backups/*/opnsense/

# Copy config to OPNsense
scp backups/latest/opnsense/config.xml root@10.0.0.1:/conf/config.xml

# Reload configuration
ssh root@10.0.0.1 "configctl filter reload"
```

#### Step 5: Verify Recovery
```bash
# Run connectivity tests
./scripts/test.sh connectivity --from-tailnet

# Verify firewall rules
./scripts/test.sh security
```

---

### Proxmox Recovery

**Scenario**: Proxmox VM is unresponsive or corrupted

**RTO**: 45 minutes

#### Step 1: Assess Access
```bash
# Try SSH via Tailscale
ssh root@10.0.0.10

# Or via OPNsense
ssh root@10.0.0.1 "ssh root@10.0.0.10 hostname"
```

#### Step 2: Attempt VM Restart
```bash
# From VPS console
ssh root@<vps-public-ip>
virsh destroy proxmox
virsh start proxmox
```

#### Step 3: Rebuild VM (if restart fails)
```bash
cd terraform

# Destroy and rebuild
terraform destroy -target=module.proxmox
terraform apply -target=module.proxmox

# Reconfigure
cd ../ansible
ansible-playbook playbooks/proxmox.yml
```

#### Step 4: Restore Configuration
```bash
# Restore storage configuration
scp backups/latest/proxmox/storage.cfg root@10.0.0.10:/etc/pve/

# Restore network configuration
scp backups/latest/proxmox/interfaces root@10.0.0.10:/etc/network/

# Restart services
ssh root@10.0.0.10 "systemctl restart pve-cluster"
```

#### Step 5: Verify Recovery
```bash
# Test web UI access
curl -k https://10.0.0.10:8006

# Run Proxmox tests
./scripts/test.sh proxmox
```

---

### Tailscale Recovery

**Scenario**: Tailscale VPN disconnected or not routing

**RTO**: 10 minutes

#### Step 1: Check Tailscale Status
```bash
# On OPNsense
ssh root@10.0.0.1 "tailscale status"
```

#### Step 2: Reconnect Tailscale
```bash
# Re-authenticate if needed
ssh root@10.0.0.1 "tailscale up --authkey=<key> --advertise-routes=10.0.0.0/24"
```

#### Step 3: Approve Routes
1. Go to https://login.tailscale.com/admin/machines
2. Find `opnsense-vps` node
3. Click the machine → "Edit route settings"
4. Enable "Subnet routes" for 10.0.0.0/24
5. Click "Save"

#### Step 4: Verify
```bash
# From home network
tailscale ping opnsense-vps
ping 10.0.0.1
ping 10.0.0.10
```

---

### Full Infrastructure Recovery

**Scenario**: Complete VPS failure or redeployment needed

**RTO**: 2 hours

#### Phase 1: VPS Preparation (15 min)

1. **Provision new VPS** (if needed)
   - SSDNodes dashboard → Deploy new KVM VPS
   - Ubuntu 22.04 LTS
   - Minimum: 8 vCPU, 64GB RAM, 800GB storage

2. **Update inventory**
   ```bash
   vim ansible/inventory/hosts.yml
   # Update vps_public_ip if changed
   ```

3. **Verify SSH access**
   ```bash
   ssh root@<new-vps-ip> "hostname"
   ```

#### Phase 2: Bootstrap Infrastructure (30 min)

```bash
# Full deployment
./scripts/deploy.sh deploy

# Or step by step:
./scripts/deploy.sh bootstrap
./scripts/deploy.sh opnsense
./scripts/deploy.sh tailscale
./scripts/deploy.sh proxmox
```

#### Phase 3: Tailscale Configuration (10 min)

1. Remove old node from Tailscale admin (if exists)
2. Approve new subnet routes
3. Verify connectivity from home network

#### Phase 4: Restore Configurations (30 min)

```bash
# Restore OPNsense config
scp backups/latest/opnsense/config.xml root@10.0.0.1:/conf/config.xml
ssh root@10.0.0.1 "configctl filter reload"

# Restore Proxmox config
scp -r backups/latest/proxmox/ root@10.0.0.10:/tmp/
ssh root@10.0.0.10 "cp /tmp/proxmox/storage.cfg /etc/pve/"
```

#### Phase 5: Validation (15 min)

```bash
# Run full test suite
./scripts/test.sh all --from-tailnet

# Manual verification checklist
echo "
[ ] OPNsense WebUI accessible at https://10.0.0.1:443
[ ] Proxmox WebUI accessible at https://10.0.0.10:8006
[ ] Tailscale subnet route approved and working
[ ] Firewall rules enforced (test port scan)
[ ] All VMs can reach internet via OPNsense
"
```

---

### Restore from Backup

**Scenario**: Need to restore specific configuration from backup

#### List Available Backups
```bash
ls -la backups/
# Or check remote backups
ssh backup-host "ls ~/cloudenv-backups/"
```

#### Restore Terraform State
```bash
# Find state backup
ls backups/*/terraform/terraform.tfstate

# Restore
cp backups/cloudenv-backup-TIMESTAMP/terraform/terraform.tfstate terraform/

# Verify
terraform plan
```

#### Restore Ansible Inventory
```bash
cp -r backups/cloudenv-backup-TIMESTAMP/ansible/inventory/* ansible/inventory/
```

#### Restore OPNsense Configuration
```bash
# Copy config
scp backups/cloudenv-backup-TIMESTAMP/opnsense/config.xml root@10.0.0.1:/conf/config.xml

# Reload (no reboot needed)
ssh root@10.0.0.1 "configctl filter reload"
```

---

## Preventive Measures

### Regular Backups
```bash
# Schedule daily backups
./scripts/backup.sh --compress --remote backup-host

# Verify backup integrity monthly
./scripts/backup.sh --verify
```

### Monitoring Checklist
- [ ] Daily: Tailscale connectivity from home
- [ ] Weekly: Test backup restoration
- [ ] Monthly: Full DR drill

### Configuration Changes
1. Always backup before changes: `./scripts/backup.sh`
2. Test in isolation when possible
3. Document changes in commit messages
4. Verify with `./scripts/test.sh`

---

## Post-Recovery Checklist

After any recovery procedure:

- [ ] All services responding
- [ ] Firewall rules verified
- [ ] Tailscale routes approved
- [ ] Backups scheduled
- [ ] Documentation updated
- [ ] Lessons learned recorded

---

## Recovery Validation Test

Perform this test quarterly to verify SC-006 (2-hour RTO):

```bash
# Create checkpoint backup
./scripts/backup.sh --compress --encrypt

# Record start time
START_TIME=$(date +%s)

# Destroy infrastructure (dry-run first!)
./scripts/destroy.sh --dry-run

# Execute full recovery
./scripts/deploy.sh deploy

# Restore configurations
# ... (restoration steps)

# Run validation
./scripts/test.sh all --from-tailnet

# Calculate recovery time
END_TIME=$(date +%s)
RECOVERY_TIME=$((END_TIME - START_TIME))
echo "Recovery completed in $((RECOVERY_TIME / 60)) minutes"

# Verify RTO met
if [ $RECOVERY_TIME -le 7200 ]; then
  echo "✅ RTO requirement met (< 2 hours)"
else
  echo "❌ RTO requirement NOT met - investigate and improve"
fi
```

---

## Appendix: Emergency Commands

```bash
# Quick status check
./scripts/test.sh --quick

# Force Terraform refresh
terraform refresh

# Emergency SSH via VPS console
# Use SSDNodes dashboard → Console access

# Reset Tailscale completely
ssh root@10.0.0.1 "tailscale down; rm -rf /var/lib/tailscale; tailscale up"

# Emergency firewall disable (temporary)
ssh root@10.0.0.1 "pfctl -d"  # DANGER: Disables all firewall rules
```

---

*Last Updated: Auto-generated*
*RTO Target: 2 hours (SC-006)*
*Constitution II: Reliability Through Simplicity*
