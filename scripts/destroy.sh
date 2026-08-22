#!/usr/bin/env bash
# T065: CloudEnv Infrastructure Destruction Script
# Constitution I: Security-First - Secure cleanup
# Safely destroys all infrastructure with confirmation

set -euo pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

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
CloudEnv Destruction Script

Usage: $(basename "$0") [OPTIONS]

Options:
    -h, --help          Show this help message
    -f, --force         Skip confirmation prompts (dangerous!)
    --keep-state        Keep Terraform state files for audit
    --backup-first      Create backup before destruction
    --dry-run           Show what would be destroyed without doing it

Examples:
    $(basename "$0")                # Interactive destruction
    $(basename "$0") --backup-first # Backup then destroy
    $(basename "$0") --dry-run      # Preview only

WARNING: This script will PERMANENTLY destroy all infrastructure!

EOF
}

# Create backup before destruction
create_backup() {
    log_info "Creating backup before destruction..."

    local backup_dir="$PROJECT_ROOT/backups/pre-destroy-$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$backup_dir"

    # Backup Terraform state
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        cp "$PROJECT_ROOT/terraform/terraform.tfstate" "$backup_dir/"
        log_success "Terraform state backed up"
    fi

    # Backup Ansible inventory
    if [[ -d "$PROJECT_ROOT/ansible/inventory" ]]; then
        cp -r "$PROJECT_ROOT/ansible/inventory" "$backup_dir/"
        log_success "Ansible inventory backed up"
    fi

    # Try to backup OPNsense config via Ansible (if reachable)
    if ansible firewalls -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m ping -o 2>/dev/null; then
        log_info "Attempting OPNsense configuration backup..."
        ansible firewalls -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m raw \
            -a "cat /conf/config.xml" > "$backup_dir/opnsense-config.xml" 2>/dev/null || \
            log_warn "Could not backup OPNsense configuration"
    fi

    log_success "Backup created at: $backup_dir"
    echo "$backup_dir"
}

# Show what will be destroyed
show_destruction_plan() {
    log_info "=== Destruction Plan ==="
    echo ""

    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        log_info "Terraform resources to be destroyed:"
        cd "$PROJECT_ROOT/terraform"
        terraform plan -destroy -no-color 2>/dev/null | head -50 || echo "  (could not read plan)"
        cd "$PROJECT_ROOT"
    else
        log_warn "No Terraform state found"
    fi

    echo ""
    log_warn "The following will be permanently deleted:"
    echo "  - OPNsense VM and all firewall configurations"
    echo "  - Proxmox VM and all storage data"
    echo "  - Private network (10.0.0.0/24)"
    echo "  - Tailscale node registration"
    echo "  - All VM disk images"
    echo ""
}

# Destroy infrastructure
destroy_infrastructure() {
    local keep_state="${1:-false}"

    log_warn "Starting infrastructure destruction..."

    # Step 1: Terraform destroy
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        log_info "Destroying Terraform-managed resources..."
        cd "$PROJECT_ROOT/terraform"
        terraform destroy -auto-approve
        cd "$PROJECT_ROOT"
        log_success "Terraform resources destroyed"
    else
        log_warn "No Terraform state to destroy"
    fi

    # Step 2: Clean up orphan libvirt resources (if any)
    log_info "Checking for orphan libvirt resources..."
    if command -v virsh &>/dev/null; then
        # List and optionally clean orphan VMs
        local orphan_vms
        orphan_vms=$(virsh list --all --name 2>/dev/null | grep -E "opnsense|proxmox" || true)
        if [[ -n "$orphan_vms" ]]; then
            log_warn "Found orphan VMs: $orphan_vms"
            log_info "Run 'virsh destroy <vm> && virsh undefine <vm>' to remove"
        fi
    fi

    # Step 3: Clean up Terraform files (unless keeping state)
    if [[ "$keep_state" == "false" ]]; then
        log_info "Cleaning up Terraform working files..."
        rm -f "$PROJECT_ROOT/terraform/terraform.tfstate"
        rm -f "$PROJECT_ROOT/terraform/terraform.tfstate.backup"
        rm -f "$PROJECT_ROOT/terraform/tfplan"
        rm -rf "$PROJECT_ROOT/terraform/.terraform"
        log_success "Terraform files cleaned"
    else
        log_info "Keeping Terraform state files for audit"
    fi

    # Step 4: Remove Tailscale device (manual step)
    log_warn "MANUAL STEP REQUIRED:"
    echo "  Remove the device from Tailscale admin console:"
    echo "  https://login.tailscale.com/admin/machines"
    echo "  Find 'opnsense-vps' and remove it"
    echo ""

    log_success "Infrastructure destruction complete"
}

main() {
    local force="false"
    local keep_state="false"
    local backup_first="false"
    local dry_run="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -f|--force)
                force="true"
                shift
                ;;
            --keep-state)
                keep_state="true"
                shift
                ;;
            --backup-first)
                backup_first="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
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
    echo "   CloudEnv Infrastructure Destruction"
    echo "========================================"
    echo ""

    # Show what will be destroyed
    show_destruction_plan

    if [[ "$dry_run" == "true" ]]; then
        log_info "Dry run complete. No changes made."
        exit 0
    fi

    # Confirmation
    if [[ "$force" != "true" ]]; then
        log_warn "This action is IRREVERSIBLE!"
        echo ""
        read -rp "Type 'DESTROY' to confirm: " confirm
        if [[ "$confirm" != "DESTROY" ]]; then
            log_info "Destruction cancelled"
            exit 0
        fi
    fi

    # Backup if requested
    if [[ "$backup_first" == "true" ]]; then
        create_backup
    fi

    # Destroy
    destroy_infrastructure "$keep_state"

    echo ""
    log_success "Destruction complete"
    echo ""
    echo "To rebuild infrastructure:"
    echo "  ./scripts/deploy.sh deploy"
}

main "$@"
