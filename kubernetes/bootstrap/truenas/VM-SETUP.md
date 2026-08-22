# TrueNAS Scale VM Setup Guide

This document covers the complete TrueNAS Scale VM creation and configuration process for the Kubernetes cluster storage backend.

## Prerequisites

- Proxmox VE 9.1.2+ host with adequate resources
- TrueNAS Scale 24.10.x ISO (download from [truenas.com](https://www.truenas.com/download-truenas-scale/))
- Tailscale network access to Proxmox host
- At least 200GB additional storage for ZFS pool

## VM Specifications

| Setting | Value | Rationale |
|---------|-------|-----------|
| VM ID | 200 | Reserved range for infrastructure |
| Name | truenas-scale | Descriptive naming |
| OS Type | Linux 6.x - 2.6 Kernel | TrueNAS Scale base |
| CPU | 2 cores (host type) | Adequate for NFS workload |
| RAM | 16384 MB | ZFS ARC cache requirement |
| Disk 1 (OS) | 100 GB, VirtIO SCSI | TrueNAS system |
| Disk 2 (Pool) | 200 GB, VirtIO SCSI | ZFS storage pool |
| Network | vmbr1, VirtIO | Internal bridge network |

## Step-by-Step VM Creation (Proxmox UI)

### 1. Upload TrueNAS ISO

1. Access Proxmox UI: `https://<proxmox-ip>:8006`
2. Navigate: Datacenter → pve-vps → local (pve-vps) → ISO Images
3. Click **Upload** and select `TrueNAS-SCALE-24.10.x.iso`
4. Wait for upload completion

### 2. Create Virtual Machine

1. Click **Create VM** in top right
2. **General Tab**:
   - VM ID: `200`
   - Name: `truenas-scale`
   - Resource Pool: (leave default)

3. **OS Tab**:
   - Use CD/DVD disc image file (iso)
   - Storage: `local`
   - ISO image: `TrueNAS-SCALE-24.10.x.iso`
   - Guest OS Type: `Linux`
   - Version: `6.x - 2.6 Kernel`

4. **System Tab**:
   - Graphic card: `Default`
   - Machine: `q35`
   - BIOS: `OVMF (UEFI)`
   - Add EFI Disk: `Yes`
   - EFI Storage: `local-lvm`
   - SCSI Controller: `VirtIO SCSI single`

5. **Disks Tab**:
   - Bus/Device: `VirtIO Block`
   - Storage: `local-lvm`
   - Disk size: `100 GiB`
   - Cache: `Write back`
   - Discard: `Yes`
   - SSD emulation: `Yes` (if on SSD)

6. **CPU Tab**:
   - Sockets: `1`
   - Cores: `2`
   - Type: `host` (for best performance)

7. **Memory Tab**:
   - Memory: `16384 MiB`
   - Minimum memory: `16384 MiB`
   - Ballooning Device: `No` (ZFS needs consistent memory)

8. **Network Tab**:
   - Bridge: `vmbr1` (internal network)
   - Model: `VirtIO (paravirtualized)`
   - Firewall: `No` (internal network)

9. **Confirm Tab**:
   - Review settings
   - Check "Start after created": `No`
   - Click **Finish**

### 3. Add Second Disk for ZFS Pool

1. Select VM 200 in left panel
2. Navigate to **Hardware** tab
3. Click **Add** → **Hard Disk**
4. Configure:
   - Bus/Device: `VirtIO Block` (virtio1)
   - Storage: `local-lvm`
   - Disk size: `200 GiB`
   - Cache: `Write back`
   - Discard: `Yes`
5. Click **Add**

### 4. Install TrueNAS Scale

1. Start VM 200
2. Open Console (noVNC or xterm.js)
3. Boot from ISO and follow TrueNAS installer:
   - Select "Install/Upgrade"
   - Choose first disk (100GB) for installation
   - Set root password
   - Wait for installation to complete
4. Remove ISO from boot order:
   - VM → Hardware → CD/DVD Drive → Do not use any media
5. Reboot VM

## Initial TrueNAS Configuration

### 5. Configure Network (T011)

After TrueNAS boots, access console to set initial network:

1. From TrueNAS console menu, select **Configure Network Interfaces**
2. Or access Web UI from DHCP-assigned IP and configure:
   - Navigate: Network → Interfaces
   - Edit `enp0s18` (or detected interface)
   - Disable DHCP
   - Add IPv4 Address: `10.9.8.20/24`
   - Save

3. Configure Gateway:
   - Network → Global Configuration
   - IPv4 Default Gateway: `10.9.8.1`
   - Nameserver 1: `10.9.8.1`
   - Nameserver 2: `1.1.1.1`
   - Save

4. Verify connectivity:
   - System Settings → Shell
   - `ping 10.9.8.1`
   - `ping 1.1.1.1`

### 6. Create ZFS Storage Pool (T012)

1. Navigate: Storage → Create Pool
2. Pool Configuration:
   - Name: `k8s-storage`
   - Layout: Select second disk (200GB)
   - Data VDEV: `Stripe` (single disk, no redundancy for lab)
3. Click **Create**
4. Verify pool appears in Storage dashboard

### 7. Create NFS Dataset (T013)

1. Navigate: Storage → k8s-storage → Add Dataset
2. Dataset Configuration:
   - Name: `nfs`
   - Comments: `NFS share for Kubernetes persistent volumes`
   - Sync: `Standard`
   - Compression: `LZ4`
   - Enable Atime: `Off`
   - ZFS Deduplication: `Off`
3. Quotas:
   - Quota for this dataset: `180 GiB`
   - Quota warning at: `80%`
   - Quota critical at: `95%`
4. Click **Save**

### 8. Configure NFS Share (T014)

1. Navigate: Shares → UNIX Shares (NFS) → Add
2. Share Configuration:
   - Path: `/mnt/k8s-storage/nfs`
   - Comment: `Kubernetes PVC storage`
   - Enabled: `Yes`
3. Advanced Options:
   - Maproot User: `root`
   - Maproot Group: `wheel`
   - Authorized Networks: `10.9.8.0/24`
   - Authorized Hosts: (leave empty)
4. Click **Save**

### 9. Enable NFS Service (T015)

1. Navigate: Services
2. Find NFS service row
3. Enable: Toggle **Running** to ON
4. Enable: Toggle **Start Automatically** to ON
5. Click NFS row to expand configuration:
   - Bind IP Addresses: `0.0.0.0` (all interfaces)
   - NFSv4: `Enabled`
   - Number of servers: `4` (auto or 4)
6. Save changes

### 10. Create API Key for democratic-csi (T016)

1. Navigate: Credentials → Local Users → root (or admin user)
2. Click **API Keys** tab
3. Click **Add**
4. Configuration:
   - Name: `k8s-csi`
   - Expires: (leave empty for no expiration)
5. Click **Save**
6. **CRITICAL**: Copy the API key immediately - it's shown only once!
7. Store the API key securely (see T017)

## API Key Storage (T017)

The API key will be encrypted with SOPS and stored in the repository:

```bash
# Create the driver config with API key
cat > kubernetes/core/storage/democratic-csi/driver-config-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: democratic-csi-driver-config
  namespace: democratic-csi
type: Opaque
stringData:
  driver-config-file.yaml: |
    driver: freenas-nfs
    instance_id: truenas-nfs
    httpConnection:
      protocol: https
      host: 10.9.8.20
      port: 443
      apiKey: "YOUR_API_KEY_HERE"
      allowInsecure: true
      apiVersion: 2
    zfs:
      datasetParentName: k8s-storage/nfs
      datasetEnableQuotas: true
      datasetPermissionsMode: "0770"
      datasetPermissionsUser: root
      datasetPermissionsGroup: wheel
    nfs:
      shareHost: 10.9.8.20
      shareAllowedNetworks:
        - 10.9.8.0/24
      shareMaprootUser: root
      shareMaprootGroup: wheel
EOF

# Encrypt with SOPS
sops --encrypt driver-config-secret.yaml > driver-config-secret.enc.yaml

# Remove plaintext
rm driver-config-secret.yaml
```

## Validation (T018)

Test NFS share accessibility from a client machine:

```bash
# From any machine on the 10.9.8.0/24 network:

# Show NFS exports
showmount -e 10.9.8.20

# Expected output:
# Export list for 10.9.8.20:
# /mnt/k8s-storage/nfs 10.9.8.0/24

# Test mount (temporary)
sudo mkdir -p /tmp/nfs-test
sudo mount -t nfs 10.9.8.20:/mnt/k8s-storage/nfs /tmp/nfs-test
echo "test" | sudo tee /tmp/nfs-test/test.txt
sudo cat /tmp/nfs-test/test.txt
sudo rm /tmp/nfs-test/test.txt
sudo umount /tmp/nfs-test
sudo rmdir /tmp/nfs-test

echo "NFS validation complete!"
```

## Troubleshooting

### NFS Mount Fails

```bash
# Check if NFS service is running on TrueNAS
# TrueNAS Shell:
service nfs status

# Check exports
showmount -e localhost

# Check firewall (should be off for internal network)
# Services → NFS → Bind to 0.0.0.0
```

### Cannot Reach TrueNAS Web UI

1. Check VM is running in Proxmox
2. Verify network configuration via console
3. Check Tailscale connectivity to 10.9.8.0/24 subnet
4. Verify gateway configuration

### ZFS Pool Not Appearing

1. Check disk is attached in Proxmox Hardware tab
2. Refresh Storage page in TrueNAS
3. Check System → Boot → Devices for disk visibility

## Next Steps

After TrueNAS is configured and validated:
1. Proceed to Phase 3: Talos cluster bootstrap
2. The cluster will use this NFS share via democratic-csi
3. See [../talos/](../talos/) for Talos configuration

## References

- [TrueNAS Scale Documentation](https://www.truenas.com/docs/scale/)
- [democratic-csi for TrueNAS](https://github.com/democratic-csi/democratic-csi)
- [NFS Best Practices for Kubernetes](https://kubernetes.io/docs/concepts/storage/volumes/#nfs)
