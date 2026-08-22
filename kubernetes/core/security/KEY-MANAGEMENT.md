# SOPS/age Key Management

This document describes the key management procedures for encrypting and decrypting secrets in this repository using SOPS with age encryption.

## Overview

**Encryption Tool**: SOPS (Secrets OPerationS)
**Encryption Backend**: age (modern, simple encryption)
**Purpose**: Encrypt sensitive values (API keys, passwords, certificates) so they can be safely committed to Git

## Key Locations

| File | Purpose | Security |
|------|---------|----------|
| `~/.config/sops/age/keys.txt` | Private key (decryption) | **NEVER commit** - backup securely |
| `.sops.yaml` | Encryption rules | Can be committed |
| `*.enc.yaml` / `*.enc` | Encrypted files | Safe to commit |

## Initial Setup

### 1. Generate age Key Pair

```bash
# Create age key directory
mkdir -p ~/.config/sops/age

# Generate new age key pair
age-keygen -o ~/.config/sops/age/keys.txt

# Extract public key for .sops.yaml
grep 'public key:' ~/.config/sops/age/keys.txt
# Output: # public key: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

### 2. Configure .sops.yaml

The `.sops.yaml` file in `kubernetes/core/security/` defines encryption rules:

```yaml
creation_rules:
  # Talos secrets
  - path_regex: .*talos.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # Kubernetes secrets
  - path_regex: .*secret.*\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

  # Default rule for any other sensitive files
  - path_regex: .*\.enc\.yaml$
    age: age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Replace `age1xxx...` with your actual public key from step 1.

### 3. Verify Installation

```bash
# Check SOPS version
sops --version

# Check age version
age --version

# Verify key is accessible
SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt sops --version
```

## Encrypting Secrets

### Encrypt a New File

```bash
# Create the secret file (do NOT commit the unencrypted version)
cat > driver-config-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: driver-config-secret
  namespace: democratic-csi
stringData:
  driver-config.yaml: |
    driver: freenas-nfs
    httpConnection:
      host: 10.9.8.20
      apiKey: YOUR_TRUENAS_API_KEY
EOF

# Encrypt the file
sops --encrypt driver-config-secret.yaml > driver-config-secret.enc.yaml

# Verify encryption worked
cat driver-config-secret.enc.yaml
# Should show encrypted values with "ENC[AES256_GCM,data:...]"

# Delete the unencrypted file
rm driver-config-secret.yaml
```

### Encrypt In-Place

```bash
# Encrypt file in place (modifies original)
sops --encrypt --in-place secrets.yaml

# This will rename to .enc or modify the file directly
```

### Encrypt Specific Values Only

```bash
# Encrypt only values, not keys
sops --encrypt --encrypted-regex '^(data|stringData)$' secret.yaml > secret.enc.yaml
```

## Decrypting Secrets

### View Decrypted Content

```bash
# View decrypted content (temporary, not saved)
sops --decrypt driver-config-secret.enc.yaml
```

### Decrypt to File

```bash
# Decrypt to a new file
sops --decrypt driver-config-secret.enc.yaml > driver-config-secret.yaml

# Apply to cluster
kubectl apply -f driver-config-secret.yaml

# Delete unencrypted file immediately
rm driver-config-secret.yaml
```

### Edit Encrypted File

```bash
# Open in editor, save to re-encrypt
sops driver-config-secret.enc.yaml
# Opens in $EDITOR, automatically re-encrypts on save
```

## Applying Secrets to Kubernetes

### Method 1: Decrypt and Apply

```bash
# Decrypt and apply in one command (never writes to disk)
sops --decrypt driver-config-secret.enc.yaml | kubectl apply -f -
```

### Method 2: ArgoCD with SOPS Plugin

For GitOps workflows, ArgoCD can be configured with the SOPS plugin:

```yaml
# argocd-cm ConfigMap (example)
configManagementPlugins: |
  - name: sops
    generate:
      command: ["sh", "-c"]
      args: ["sops --decrypt $ARGOCD_ENV_FILE"]
```

Note: ArgoCD SOPS integration requires additional setup. See ArgoCD documentation.

## Key Backup and Recovery

### Backup Your Private Key

**CRITICAL**: The age private key is required to decrypt all secrets. If lost, encrypted secrets cannot be recovered.

```bash
# Option 1: Secure USB backup
cp ~/.config/sops/age/keys.txt /media/secure-usb/age-keys-backup.txt

# Option 2: Password-protected archive
tar -czvf - ~/.config/sops/age/keys.txt | \
  gpg --symmetric --cipher-algo AES256 > age-key-backup.tar.gz.gpg

# Option 3: Split key with Shamir's Secret Sharing
# (Advanced - use tools like `ssss`)
```

### Recovery Procedure

1. Retrieve backup of `keys.txt`
2. Place in `~/.config/sops/age/keys.txt`
3. Set permissions: `chmod 600 ~/.config/sops/age/keys.txt`
4. Test decryption: `sops --decrypt <any-encrypted-file>`

### Key Rotation

When rotating keys (e.g., team member leaves):

```bash
# 1. Generate new key pair
age-keygen -o new-keys.txt

# 2. Add new public key to .sops.yaml
# (Can have multiple keys for transition period)

# 3. Re-encrypt all secrets with new key
for f in $(find . -name "*.enc.yaml"); do
  sops --rotate --in-place "$f"
done

# 4. Remove old public key from .sops.yaml

# 5. Securely destroy old private key
shred -vuz old-keys.txt
```

## Files in This Repository

### Currently Encrypted

| File | Description |
|------|-------------|
| `kubernetes/bootstrap/talos/talossecrets.yaml.enc` | Talos cluster secrets |
| `kubernetes/core/storage/democratic-csi/driver-config-secret.enc.yaml` | TrueNAS API credentials |

### Encryption Rules (.sops.yaml)

```yaml
creation_rules:
  - path_regex: .*secrets?.*\.yaml$
    age: <your-public-key>
  - path_regex: .*\.enc\.yaml$
    age: <your-public-key>
```

## Security Best Practices

1. **Never commit unencrypted secrets** - Use `.gitignore` patterns
2. **Protect private key** - chmod 600, backup securely
3. **Rotate keys periodically** - At least annually or on team changes
4. **Use separate keys per environment** - Dev, staging, production
5. **Audit encrypted files** - Ensure all sensitive data is encrypted

### .gitignore Patterns

```gitignore
# Unencrypted secrets
secrets.yaml
*-secret.yaml
!*-secret.enc.yaml
*.key
*.pem

# Age private keys
keys.txt

# Decrypted temp files
*.dec.yaml
```

## Troubleshooting

### "age: error: no identity matched any of the recipients"

- Private key doesn't match public key used for encryption
- Check `~/.config/sops/age/keys.txt` exists and has correct key
- Verify `.sops.yaml` has correct public key

### "error decrypting key"

- Key file corrupted or wrong format
- Regenerate key or restore from backup

### "failed to get the data key required to decrypt the SOPS file"

- SOPS can't find age key
- Set environment variable: `export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`

## References

- [SOPS Documentation](https://github.com/getsops/sops)
- [age Documentation](https://github.com/FiloSottile/age)
- [Talos Secrets](https://www.talos.dev/v1.9/talos-guides/configuration/secrets/)
- [ArgoCD SOPS Plugin](https://github.com/argoproj-labs/argocd-vault-plugin)
