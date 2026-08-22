# Kubernetes Cluster Troubleshooting Guide

Common issues and solutions for the Talos Linux Kubernetes cluster.

## Table of Contents

1. [Talos Issues](#talos-issues)
2. [Kubernetes Issues](#kubernetes-issues)
3. [Storage Issues](#storage-issues)
4. [Networking Issues](#networking-issues)
5. [ArgoCD Issues](#argocd-issues)
6. [Access Issues](#access-issues)
7. [Diagnostic Commands](#diagnostic-commands)

---

## Talos Issues

### Node Not Booting / Stuck in Maintenance Mode

**Symptoms**: Node shows maintenance mode IP, won't boot into Kubernetes

**Causes & Solutions**:

1. **Configuration not applied**:
   ```bash
   # Check if config was applied
   talosctl get machineconfig --nodes <maintenance-ip>

   # Re-apply configuration
   talosctl apply-config --insecure --nodes <maintenance-ip> \
     --file kubernetes/bootstrap/talos/configurations/<node>.yaml
   ```

2. **Invalid machine config**:
   ```bash
   # Validate config before applying
   talosctl validate --mode metal \
     --config kubernetes/bootstrap/talos/configurations/<node>.yaml
   ```

3. **Network misconfiguration**:
   - Verify static IP matches network configuration
   - Check gateway and DNS settings in node patch

### etcd Cluster Unhealthy

**Symptoms**: `talosctl etcd status` shows unhealthy members

**Solutions**:

1. **Check etcd member status**:
   ```bash
   talosctl etcd members --nodes 10.9.8.100
   talosctl etcd status --nodes 10.9.8.11,10.9.8.12,10.9.8.13
   ```

2. **Single node failure** - Cluster continues with 2/3 nodes:
   ```bash
   # Check which node is down
   talosctl health --nodes 10.9.8.11,10.9.8.12,10.9.8.13

   # Fix the failing node and it will rejoin automatically
   ```

3. **Majority failure (2+ nodes)** - Recovery required:
   ```bash
   # This is a disaster scenario - etcd lost quorum
   # See Talos disaster recovery documentation
   ```

### Talos API Not Responding

**Symptoms**: `talosctl version` times out

**Solutions**:

1. **Check Tailscale connectivity**:
   ```bash
   tailscale ping 10.9.8.100
   ping -c 3 10.9.8.100
   ```

2. **Check VIP status** - Try individual nodes:
   ```bash
   talosctl version --nodes 10.9.8.11
   talosctl version --nodes 10.9.8.12
   talosctl version --nodes 10.9.8.13
   ```

3. **Verify talosconfig**:
   ```bash
   talosctl config info
   cat ~/.talos/config | grep -A5 "context:"
   ```

---

## Kubernetes Issues

### Nodes NotReady

**Symptoms**: `kubectl get nodes` shows NotReady status

**Causes & Solutions**:

1. **Cilium not running**:
   ```bash
   # Check Cilium pods
   kubectl get pods -n kube-system -l k8s-app=cilium

   # Check Cilium status
   kubectl exec -n kube-system ds/cilium -- cilium status

   # If not installed, install Cilium
   ./kubernetes/bootstrap/scripts/install-cilium.sh
   ```

2. **kubelet issues**:
   ```bash
   # Check kubelet logs via Talos
   talosctl logs kubelet --nodes 10.9.8.11 | tail -50
   ```

3. **Node resource exhaustion**:
   ```bash
   kubectl describe node <node-name> | grep -A5 "Conditions:"
   ```

### Pods Pending / Not Scheduling

**Symptoms**: Pods stuck in Pending state

**Causes & Solutions**:

1. **No available nodes**:
   ```bash
   kubectl describe pod <pod-name> | grep -A10 "Events:"
   # Look for: "no nodes available to schedule pods"
   ```

2. **Insufficient resources**:
   ```bash
   kubectl describe nodes | grep -A5 "Allocatable:"
   kubectl top nodes
   ```

3. **PVC not bound**:
   ```bash
   kubectl get pvc
   # If pending, check StorageClass and democratic-csi
   ```

4. **Taints preventing scheduling**:
   ```bash
   kubectl describe nodes | grep Taints
   # Control plane nodes may have taints - check pod tolerations
   ```

### API Server Unavailable

**Symptoms**: `kubectl` commands fail with connection errors

**Solutions**:

1. **Check VIP reachability**:
   ```bash
   curl -sk https://10.9.8.100:6443/healthz
   # Should return "ok"
   ```

2. **Verify kubeconfig**:
   ```bash
   kubectl config current-context
   kubectl config view | grep server
   # Should show https://10.9.8.100:6443
   ```

3. **Regenerate kubeconfig**:
   ```bash
   talosctl kubeconfig ~/.kube/config --force
   ```

---

## Storage Issues

### PVC Stuck in Pending

**Symptoms**: PVC shows Pending status, never becomes Bound

**Causes & Solutions**:

1. **democratic-csi not running**:
   ```bash
   kubectl get pods -n democratic-csi
   kubectl logs -n democratic-csi deployment/democratic-csi-controller
   ```

2. **StorageClass missing**:
   ```bash
   kubectl get sc
   # truenas-nfs should exist and be default
   ```

3. **TrueNAS connectivity**:
   ```bash
   # From a cluster node (via talosctl)
   talosctl shell --nodes 10.9.8.11 -- ping -c 3 10.9.8.20
   ```

4. **TrueNAS API key issues**:
   ```bash
   kubectl get secret -n democratic-csi driver-config-secret
   kubectl logs -n democratic-csi deployment/democratic-csi-controller | grep -i auth
   ```

### PV Not Cleaning Up

**Symptoms**: PV stuck in Released state after PVC deletion

**Solutions**:

1. **Check reclaim policy**:
   ```bash
   kubectl get pv <pv-name> -o yaml | grep persistentVolumeReclaimPolicy
   # Should be "Delete" for automatic cleanup
   ```

2. **Manual cleanup**:
   ```bash
   kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'
   kubectl delete pv <pv-name>
   ```

### NFS Mount Failures

**Symptoms**: Pods fail to start with NFS mount errors

**Solutions**:

1. **Verify NFS service on TrueNAS**:
   - TrueNAS UI → Services → NFS → Ensure running

2. **Check NFS share permissions**:
   - TrueNAS UI → Shares → NFS
   - Network should include 10.9.8.0/24

3. **Test NFS from node**:
   ```bash
   # Via talosctl (limited in Talos)
   talosctl dmesg --nodes 10.9.8.11 | grep -i nfs
   ```

---

## Networking Issues

### Pods Can't Communicate

**Symptoms**: Pod-to-pod or pod-to-service communication fails

**Solutions**:

1. **Check Cilium health**:
   ```bash
   kubectl exec -n kube-system ds/cilium -- cilium status
   kubectl exec -n kube-system ds/cilium -- cilium-health status
   ```

2. **Verify endpoints**:
   ```bash
   kubectl get endpoints <service-name>
   # Should show pod IPs
   ```

3. **Check Cilium connectivity**:
   ```bash
   kubectl exec -n kube-system ds/cilium -- cilium connectivity test
   ```

### External Access Not Working

**Symptoms**: NodePort or LoadBalancer services unreachable

**Solutions**:

1. **Verify service configuration**:
   ```bash
   kubectl get svc <service-name> -o wide
   kubectl describe svc <service-name>
   ```

2. **Check Cilium kube-proxy replacement**:
   ```bash
   kubectl exec -n kube-system ds/cilium -- cilium status | grep KubeProxyReplacement
   # Should show "True" or "Strict"
   ```

3. **Firewall/Tailscale issues**:
   ```bash
   # Test from Tailscale-connected device
   curl -k https://10.9.8.11:<nodeport>
   ```

---

## ArgoCD Issues

### ArgoCD UI Not Accessible

**Symptoms**: Can't access ArgoCD web interface

**Solutions**:

1. **Check ArgoCD pods**:
   ```bash
   kubectl get pods -n argocd
   kubectl logs -n argocd deployment/argocd-server
   ```

2. **Port-forward to access**:
   ```bash
   kubectl port-forward svc/argocd-server -n argocd 8080:443
   # Access https://localhost:8080
   ```

3. **Get admin password**:
   ```bash
   kubectl -n argocd get secret argocd-initial-admin-secret \
     -o jsonpath="{.data.password}" | base64 -d && echo
   ```

### Application Not Syncing

**Symptoms**: ArgoCD Application shows OutOfSync or Error

**Solutions**:

1. **Check Application status**:
   ```bash
   kubectl get application -n argocd
   kubectl describe application <app-name> -n argocd
   ```

2. **View sync errors**:
   ```bash
   kubectl get application <app-name> -n argocd -o yaml | grep -A20 "status:"
   ```

3. **Force sync**:
   ```bash
   argocd app sync <app-name> --force
   # Or via UI: click Sync → Force
   ```

4. **Repository access issues**:
   ```bash
   kubectl logs -n argocd deployment/argocd-repo-server
   ```

---

## Access Issues

### Tailscale Connectivity Problems

**Symptoms**: Can't reach cluster from remote device

**Solutions**:

1. **Check Tailscale status**:
   ```bash
   tailscale status
   tailscale ping 10.9.8.100
   ```

2. **Verify subnet routes**:
   ```bash
   # Check if 10.9.8.0/24 is being advertised
   tailscale status --json | jq '.Peer[] | select(.HostName=="<subnet-router>") | .AllowedIPs'
   ```

3. **Check ACLs**:
   - Tailscale Admin Console → Access Controls
   - Ensure your device has access to 10.9.8.0/24

### talosctl/kubectl Authentication Failures

**Symptoms**: Commands fail with authentication or certificate errors

**Solutions**:

1. **Check config file permissions**:
   ```bash
   ls -la ~/.talos/config ~/.kube/config
   # Should be 600 or 644
   chmod 600 ~/.talos/config ~/.kube/config
   ```

2. **Regenerate credentials**:
   ```bash
   # For talosctl - regenerate from secrets
   cd kubernetes/bootstrap/talos
   talosctl gen config homelab https://10.9.8.100:6443 \
     --output-types talosconfig \
     --with-secrets secrets.yaml
   cp talosconfig ~/.talos/config

   # For kubectl
   talosctl kubeconfig ~/.kube/config --force
   ```

3. **Certificate expiry**:
   ```bash
   # Check certificate expiry
   talosctl get certificate --nodes 10.9.8.100
   ```

---

## Diagnostic Commands

### Quick Health Check Script

```bash
#!/bin/bash
echo "=== Talos Health ==="
talosctl health --nodes 10.9.8.100

echo -e "\n=== Kubernetes Nodes ==="
kubectl get nodes -o wide

echo -e "\n=== System Pods ==="
kubectl get pods -n kube-system

echo -e "\n=== All Pods Not Running ==="
kubectl get pods -A | grep -v Running | grep -v Completed

echo -e "\n=== PVC Status ==="
kubectl get pvc -A

echo -e "\n=== ArgoCD Apps ==="
kubectl get applications -n argocd
```

### Talos Diagnostics

```bash
# Node logs
talosctl logs kubelet --nodes 10.9.8.11
talosctl logs containerd --nodes 10.9.8.11

# System information
talosctl get members --nodes 10.9.8.100
talosctl services --nodes 10.9.8.11

# Resource usage
talosctl dashboard --nodes 10.9.8.11
```

### Kubernetes Diagnostics

```bash
# Cluster events
kubectl get events -A --sort-by='.lastTimestamp' | tail -30

# Resource usage
kubectl top nodes
kubectl top pods -A

# Describe problematic resources
kubectl describe node <node-name>
kubectl describe pod <pod-name> -n <namespace>
```

---

## Getting Help

1. **Talos Documentation**: https://www.talos.dev/docs/
2. **Cilium Documentation**: https://docs.cilium.io/
3. **democratic-csi**: https://github.com/democratic-csi/democratic-csi
4. **ArgoCD Documentation**: https://argo-cd.readthedocs.io/

For cluster-specific issues, run the smoke tests:

```bash
./kubernetes/tests/smoke/cluster-health.sh
./kubernetes/tests/smoke/storage-test.sh
./kubernetes/tests/smoke/argocd-test.sh
./kubernetes/tests/smoke/access-test.sh
```
