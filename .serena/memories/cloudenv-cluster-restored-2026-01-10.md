# CloudEnv Cluster Restored - 2026-01-10

## Issue
Talos VMs booting from ISO instead of disk (boot order: ide2;scsi0)

## Fix
Changed boot order to scsi0 only for VMs 201, 202, 203

## Current State
- Talos: v1.12.0 (upgraded from v1.9.1)
- Kubernetes: v1.31.4
- Nodes: 3 control plane (10.0.0.11-13)
- VIP: 10.0.0.100
- ArgoCD: Running
- Cilium: Running
- Proxmox host: vmhost-cloud1

## Access
- Kubeconfig: ~/.kube/cloudenv-config
- Talosconfig: ~/.talos/config (endpoint fixed)
- Proxmox SSH: root@10.0.0.1

## Pending Tasks
- TrueNAS setup (VM 200)
- Democratic CSI installation
- Tailscale direct connectivity (iptables issue on workstation)
