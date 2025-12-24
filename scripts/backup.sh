#!/usr/bin/env bash
# T066: CloudEnv Backup Script
# Constitution I: Security-First - Secure backup of sensitive configs
# Constitution II: Reliability - Disaster recovery preparation

set -euo pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default backup location
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_ROOT/backups}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

usage() {
    cat << EOF
CloudEnv Backup Script

Usage: $(basename "$0") [OPTIONS] [BACKUP_TYPE]

Backup Types:
    all         Full backup (default)
    terraform   Terraform state only
    opnsense    OPNsense configuration only
    proxmox     Proxmox configuration only
    ansible     Ansible inventory and vault only

Options:
    -h, --help              Show this help message
    -o, --output DIR        Backup output directory (default: ./backups)
    --encrypt               Encrypt backup with GPG
    --compress              Compress backup with gzip
    --remote HOST           Copy backup to remote host

Examples:
    $(basename "$0")                        # Full backup
    $(basename "$0") opnsense               # OPNsense config only
    $(basename "$0") --encrypt --compress   # Encrypted compressed backup

EOF
}

# Create backup directory with timestamp
create_backup_dir() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_path="$BACKUP_DIR/cloudenv-backup-$timestamp"
    mkdir -p "$backup_path"
    echo "$backup_path"
}

# Backup Terraform state
backup_terraform() {
    local dest="$1"

    log_info "Backing up Terraform state..."
    mkdir -p "$dest/terraform"

    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cp "$PROJECT_ROOT/terraform/terraform.tfstate" "$dest/terraform/"
        log_success "Terraform state backed up"
    else
        log_warn "No Terraform state found"
    fi

    # Backup tfvars (without secrets - should use vault)
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfvars" ]]; then
        cp "$PROJECT_ROOT/terraform/terraform.tfvars" "$dest/terraform/"
    fi
}

# Backup OPNsense configuration
backup_opnsense() {
    local dest="$1"

    log_info "Backing up OPNsense configuration..."
    mkdir -p "$dest/opnsense"

    # Check if OPNsense is reachable
    if ! ansible firewalls -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m ping -o 2>/dev/null; then
        log_warn "OPNsense not reachable via Ansible"
        log_info "Attempting direct SSH backup..."

        # Try direct SSH
        local opnsense_ip="10.0.0.1"
        if ssh -o ConnectTimeout=5 root@"$opnsense_ip" "cat /conf/config.xml" > "$dest/opnsense/config.xml" 2>/dev/null; then
            log_success "OPNsense config backed up via SSH"
        else
            log_error "Could not backup OPNsense configuration"
            return 1
        fi
    else
        # Backup via Ansible
        ansible firewalls -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
            -a "cat /conf/config.xml" > "$dest/opnsense/config.xml" 2>/dev/null

        # Backup Tailscale state if present
        ansible firewalls -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
            -a "tailscale status --json 2>/dev/null || echo '{}'" > "$dest/opnsense/tailscale-status.json" 2>/dev/null || true

        log_success "OPNsense configuration backed up"
    fi
}

# Backup Proxmox configuration
backup_proxmox() {
    local dest="$1"

    log_info "Backing up Proxmox configuration..."
    mkdir -p "$dest/proxmox"

    local proxmox_ip="10.0.0.10"

    # Check if Proxmox is reachable
    if ! ansible proxmox -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m ping -o 2>/dev/null; then
        log_warn "Proxmox not reachable"
        return 1
    fi

    # Backup storage configuration
    ansible proxmox -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
        -a "cat /etc/pve/storage.cfg" > "$dest/proxmox/storage.cfg" 2>/dev/null || true

    # Backup network configuration
    ansible proxmox -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
        -a "cat /etc/network/interfaces" > "$dest/proxmox/interfaces" 2>/dev/null || true

    # Backup datacenter configuration
    ansible proxmox -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
        -a "cat /etc/pve/datacenter.cfg" > "$dest/proxmox/datacenter.cfg" 2>/dev/null || true

    # List VMs for reference
    ansible proxmox -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
        -a "qm list" > "$dest/proxmox/vm-list.txt" 2>/dev/null || true

    log_success "Proxmox configuration backed up"
}

# Backup Ansible inventory and configuration
backup_ansible() {
    local dest="$1"

    log_info "Backing up Ansible inventory and configuration..."
    mkdir -p "$dest/ansible"

    # Backup inventory
    cp -r "$PROJECT_ROOT/ansible/inventory" "$dest/ansible/"

    # Backup ansible.cfg
    if [[ -f "$PROJECT_ROOT/ansible/ansible.cfg" ]]; then
        cp "$PROJECT_ROOT/ansible/ansible.cfg" "$dest/ansible/"
    fi

    log_success "Ansible configuration backed up"
}

# Compress backup
compress_backup() {
    local backup_path="$1"

    log_info "Compressing backup..."

    local archive="${backup_path}.tar.gz"
    tar -czf "$archive" -C "$(dirname "$backup_path")" "$(basename "$backup_path")"
    rm -rf "$backup_path"

    log_success "Backup compressed: $archive"
    echo "$archive"
}

# Encrypt backup
encrypt_backup() {
    local backup_path="$1"

    log_info "Encrypting backup..."

    local encrypted="${backup_path}.gpg"
    gpg --symmetric --cipher-algo AES256 -o "$encrypted" "$backup_path"
    rm -f "$backup_path"

    log_success "Backup encrypted: $encrypted"
    echo "$encrypted"
}

# Copy backup to remote host
copy_to_remote() {
    local backup_path="$1"
    local remote_host="$2"

    log_info "Copying backup to $remote_host..."

    scp "$backup_path" "${remote_host}:~/cloudenv-backups/"

    log_success "Backup copied to $remote_host"
}

main() {
    local backup_type="all"
    local do_compress="false"
    local do_encrypt="false"
    local remote_host=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -o|--output)
                BACKUP_DIR="$2"
                shift 2
                ;;
            --compress)
                do_compress="true"
                shift
                ;;
            --encrypt)
                do_encrypt="true"
                shift
                ;;
            --remote)
                remote_host="$2"
                shift 2
                ;;
            terraform|opnsense|proxmox|ansible|all)
                backup_type="$1"
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo ""
    echo "========================================"
    echo "   CloudEnv Backup"
    echo "========================================"
    echo ""

    # Create backup directory
    local backup_path
    backup_path=$(create_backup_dir)
    log_info "Backup directory: $backup_path"

    # Run backups based on type
    case "$backup_type" in
        terraform)
            backup_terraform "$backup_path"
            ;;
        opnsense)
            backup_opnsense "$backup_path"
            ;;
        proxmox)
            backup_proxmox "$backup_path"
            ;;
        ansible)
            backup_ansible "$backup_path"
            ;;
        all)
            backup_terraform "$backup_path" || true
            backup_ansible "$backup_path"
            backup_opnsense "$backup_path" || true
            backup_proxmox "$backup_path" || true
            ;;
    esac

    # Create manifest
    log_info "Creating backup manifest..."
    cat > "$backup_path/MANIFEST.txt" << EOF
CloudEnv Backup Manifest
========================
Date: $(date)
Type: $backup_type
Host: $(hostname)

Contents:
$(ls -la "$backup_path")

Restore Instructions:
1. Extract backup archive
2. Review MANIFEST.txt
3. Use ./scripts/deploy.sh to rebuild infrastructure
4. Restore configurations from backup files
EOF

    log_success "Manifest created"

    # Post-processing
    local final_path="$backup_path"

    if [[ "$do_compress" == "true" ]]; then
        final_path=$(compress_backup "$final_path")
    fi

    if [[ "$do_encrypt" == "true" ]]; then
        final_path=$(encrypt_backup "$final_path")
    fi

    if [[ -n "$remote_host" ]]; then
        copy_to_remote "$final_path" "$remote_host"
    fi

    echo ""
    log_success "Backup complete!"
    echo "Location: $final_path"
    echo ""
}

main "$@"
