# Kubernetes Cluster Access Configuration

This document describes how to configure and verify access to the Kubernetes cluster via Tailscale.

## Prerequisites

1. **Tailscale installed** on your client device
2. **Tailscale connected** to the same tailnet as the home network
3. **Subnet routes enabled** for the 10.9.8.0/24 network via a Tailscale exit node or subnet router

## Network Configuration

### Cluster Endpoints

| Service | IP Address | Port | Description |
|---------|------------|------|-------------|
| Talos VIP | 10.9.8.100 | 6443 | Kubernetes API (HA endpoint) |
| Talos VIP | 10.9.8.100 | 50000 | Talos API (HA endpoint) |
| talos-cp-1 | 10.9.8.11 | 50000 | Talos API (direct) |
| talos-cp-2 | 10.9.8.12 | 50000 | Talos API (direct) |
| talos-cp-3 | 10.9.8.13 | 50000 | Talos API (direct) |
| TrueNAS | 10.9.8.20 | 443 | TrueNAS Web UI |
| TrueNAS | 10.9.8.20 | 2049 | NFS |

### Tailscale Subnet Access

Ensure your Tailscale setup routes traffic to `10.9.8.0/24`. This can be achieved via:

1. **Subnet Router**: A device on the home network advertising the subnet
2. **Exit Node**: Routing all traffic through a home network exit node

To verify Tailscale connectivity:

```bash
# Check if subnet is accessible
tailscale status
tailscale ping 10.9.8.100
```

## Talos Configuration

### talosconfig Setup

The `talosconfig` file contains credentials for accessing Talos nodes via the API.

**Location**: `~/.talos/config` (default)

**Configuration**:

```yaml
context: homelab
contexts:
  homelab:
    endpoints:
      - 10.9.8.100
    nodes:
      - 10.9.8.11
      - 10.9.8.12
      - 10.9.8.13
    ca: <base64-encoded-ca>
    crt: <base64-encoded-client-cert>
    key: <base64-encoded-client-key>
```

### Generating talosconfig

After cluster bootstrap, generate the talosconfig:

```bash
# From the bootstrap directory with secrets.yaml
talosctl gen config homelab https://10.9.8.100:6443 \
  --output-types talosconfig \
  --with-secrets secrets.yaml

# Copy to default location
mkdir -p ~/.talos
cp talosconfig ~/.talos/config
chmod 600 ~/.talos/config
```

### Verifying Talos Access

```bash
# Test API connectivity
talosctl version

# Check cluster health
talosctl health

# List nodes
talosctl get members
```

## Kubernetes Configuration

### kubeconfig Setup

The `kubeconfig` file contains credentials for accessing the Kubernetes API.

**Location**: `~/.kube/config` (default)

### Generating kubeconfig

After cluster bootstrap, generate the kubeconfig:

```bash
# Using talosctl
talosctl kubeconfig ~/.kube/config

# Verify the server endpoint (should be VIP)
cat ~/.kube/config | grep server
# Expected: server: https://10.9.8.100:6443
```

### Verifying Kubernetes Access

```bash
# Test API connectivity
kubectl cluster-info

# List nodes
kubectl get nodes

# Check all pods
kubectl get pods -A
```

## ArgoCD Access

### Port-Forward Access (Recommended for Initial Setup)

```bash
# Forward ArgoCD server to localhost
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access UI at: https://localhost:8080
```

### Get Admin Password

```bash
# Retrieve initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
```

### ArgoCD CLI Setup

```bash
# Install ArgoCD CLI
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/

# Login (after port-forward)
argocd login localhost:8080 --username admin --password <password> --insecure
```

## Troubleshooting

### Cannot Connect to Talos API

1. **Check Tailscale connectivity**:
   ```bash
   tailscale ping 10.9.8.100
   ```

2. **Verify VIP is responding**:
   ```bash
   curl -k https://10.9.8.100:50000/version
   ```

3. **Check individual node**:
   ```bash
   talosctl --nodes 10.9.8.11 version
   ```

### Cannot Connect to Kubernetes API

1. **Check Tailscale connectivity**:
   ```bash
   tailscale ping 10.9.8.100
   ```

2. **Verify API server**:
   ```bash
   curl -k https://10.9.8.100:6443/healthz
   ```

3. **Check kubeconfig context**:
   ```bash
   kubectl config current-context
   kubectl config get-contexts
   ```

### Slow or Intermittent Connections

1. **Check Tailscale route**:
   ```bash
   tailscale status
   # Verify subnet router is online
   ```

2. **Check network latency**:
   ```bash
   ping -c 5 10.9.8.100
   ```

3. **Verify DNS resolution** (if using hostnames):
   ```bash
   nslookup argocd.local
   ```

## Security Considerations

### Credential Security

- **talosconfig**: Contains admin-level credentials for Talos nodes
  - Store securely with `chmod 600`
  - Never commit to Git
  - Encrypt with SOPS for backup

- **kubeconfig**: Contains admin-level credentials for Kubernetes
  - Store securely with `chmod 600`
  - Never commit to Git
  - Rotate credentials periodically

### Network Security

- All API access requires valid certificates (mTLS for Talos)
- Tailscale provides encrypted tunnel with identity verification
- Consider using Tailscale ACLs to restrict cluster access

### Best Practices

1. **Use VIP for HA access** - Individual node IPs may become unavailable
2. **Secure credential files** - chmod 600, don't commit to Git
3. **Audit access regularly** - Review who has Tailscale access to the subnet
4. **Rotate credentials** - Regenerate certificates periodically
5. **Monitor access logs** - Check Talos and Kubernetes audit logs
