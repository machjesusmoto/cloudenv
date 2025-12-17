#!/usr/bin/env bash
# CloudEnv Deployment Orchestration Script
# Constitution II: Reliability Through Simplicity
# Constitution III: Infrastructure as Code

set -euo pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Help message
usage() {
    cat << EOF
CloudEnv Deployment Script

Usage: $(basename "$0") [COMMAND] [OPTIONS]

Commands:
    bootstrap       Run Ansible bootstrap playbook (initial VPS setup)
    terraform       Run Terraform operations
    opnsense        Deploy OPNsense firewall configuration
    tailscale       Deploy Tailscale VPN (requires OPNsense)
    proxmox         Deploy Proxmox VE (requires Tailscale)
    deploy          Full deployment (bootstrap + terraform + VMs)
    destroy         Destroy all infrastructure
    status          Show deployment status
    validate        Validate configuration files
    test            Run validation tests

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Show what would be done without executing
    --skip-checks   Skip pre-flight checks

Examples:
    $(basename "$0") bootstrap          # Initial VPS setup
    $(basename "$0") terraform init     # Initialize Terraform
    $(basename "$0") terraform plan     # Show Terraform plan
    $(basename "$0") terraform apply    # Apply Terraform changes
    $(basename "$0") opnsense           # Configure OPNsense firewall
    $(basename "$0") deploy             # Full deployment
    $(basename "$0") status             # Show current status
    $(basename "$0") test               # Run security/connectivity tests

EOF
}

# Pre-flight checks
preflight_checks() {
    log_info "Running pre-flight checks..."

    local errors=0

    # Check required tools
    for tool in ansible ansible-playbook terraform ssh; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            ((errors++))
        fi
    done

    # Check Ansible inventory
    if [[ ! -f "$PROJECT_ROOT/ansible/inventory/hosts.yml" ]]; then
        log_error "Ansible inventory not found: ansible/inventory/hosts.yml"
        ((errors++))
    fi

    # Check Terraform configuration
    if [[ ! -f "$PROJECT_ROOT/terraform/versions.tf" ]]; then
        log_error "Terraform configuration not found: terraform/versions.tf"
        ((errors++))
    fi

    # Check for vault password file or environment variable
    if [[ ! -f "$HOME/.ansible_vault_password" ]] && [[ -z "${ANSIBLE_VAULT_PASSWORD:-}" ]]; then
        log_warn "Ansible vault password not configured (optional for initial setup)"
    fi

    if [[ $errors -gt 0 ]]; then
        log_error "Pre-flight checks failed with $errors error(s)"
        return 1
    fi

    log_success "Pre-flight checks passed"
}

# Validate configuration files
validate_config() {
    log_info "Validating configuration files..."

    # Validate Ansible syntax
    log_info "Checking Ansible playbook syntax..."
    if ! ansible-playbook --syntax-check "$PROJECT_ROOT/ansible/playbooks/bootstrap.yml" -i "$PROJECT_ROOT/ansible/inventory/hosts.yml"; then
        log_error "Ansible syntax check failed"
        return 1
    fi

    # Validate Terraform configuration
    log_info "Checking Terraform configuration..."
    cd "$PROJECT_ROOT/terraform"
    if ! terraform validate; then
        log_error "Terraform validation failed"
        return 1
    fi
    cd "$PROJECT_ROOT"

    log_success "Configuration validation passed"
}

# Run Ansible bootstrap
run_bootstrap() {
    local extra_args=("$@")

    log_info "Running Ansible bootstrap playbook..."

    cd "$PROJECT_ROOT/ansible"

    ansible-playbook playbooks/bootstrap.yml \
        -i inventory/hosts.yml \
        "${extra_args[@]:-}"

    log_success "Bootstrap completed"
}

# Run Terraform operations
run_terraform() {
    local command="${1:-plan}"
    shift || true
    local extra_args=("$@")

    log_info "Running Terraform $command..."

    cd "$PROJECT_ROOT/terraform"

    case "$command" in
        init)
            terraform init "${extra_args[@]:-}"
            ;;
        plan)
            terraform plan -out=tfplan "${extra_args[@]:-}"
            ;;
        apply)
            if [[ -f tfplan ]]; then
                terraform apply tfplan "${extra_args[@]:-}"
            else
                terraform apply "${extra_args[@]:-}"
            fi
            ;;
        destroy)
            terraform destroy "${extra_args[@]:-}"
            ;;
        output)
            terraform output "${extra_args[@]:-}"
            ;;
        *)
            terraform "$command" "${extra_args[@]:-}"
            ;;
    esac

    cd "$PROJECT_ROOT"
    log_success "Terraform $command completed"
}

# Deploy OPNsense configuration
run_opnsense() {
    local extra_args=("$@")

    log_info "Deploying OPNsense firewall configuration..."

    cd "$PROJECT_ROOT/ansible"

    ansible-playbook playbooks/opnsense.yml \
        -i inventory/hosts.yml \
        "${extra_args[@]:-}"

    log_success "OPNsense deployment completed"
}

# Deploy Tailscale VPN
run_tailscale() {
    local extra_args=("$@")

    log_info "Deploying Tailscale VPN..."

    cd "$PROJECT_ROOT/ansible"

    if [[ ! -f playbooks/tailscale.yml ]]; then
        log_error "Tailscale playbook not found. Run Phase 4 implementation first."
        return 1
    fi

    ansible-playbook playbooks/tailscale.yml \
        -i inventory/hosts.yml \
        "${extra_args[@]:-}"

    log_success "Tailscale deployment completed"
}

# Deploy Proxmox VE
run_proxmox() {
    local extra_args=("$@")

    log_info "Deploying Proxmox VE..."

    cd "$PROJECT_ROOT/ansible"

    if [[ ! -f playbooks/proxmox.yml ]]; then
        log_error "Proxmox playbook not found. Run Phase 5 implementation first."
        return 1
    fi

    ansible-playbook playbooks/proxmox.yml \
        -i inventory/hosts.yml \
        "${extra_args[@]:-}"

    log_success "Proxmox deployment completed"
}

# Run tests
run_tests() {
    local test_type="${1:-all}"
    shift || true

    log_info "Running $test_type tests..."

    cd "$PROJECT_ROOT/ansible"

    case "$test_type" in
        security)
            ansible-playbook tests/security.yml -i inventory/hosts.yml
            ;;
        connectivity)
            if [[ -f tests/connectivity.yml ]]; then
                ansible-playbook tests/connectivity.yml -i inventory/hosts.yml
            else
                log_warn "Connectivity tests not yet implemented"
            fi
            ;;
        all)
            log_info "Running security tests..."
            ansible-playbook tests/security.yml -i inventory/hosts.yml || true

            if [[ -f tests/connectivity.yml ]]; then
                log_info "Running connectivity tests..."
                ansible-playbook tests/connectivity.yml -i inventory/hosts.yml || true
            fi
            ;;
        *)
            log_error "Unknown test type: $test_type"
            return 1
            ;;
    esac

    cd "$PROJECT_ROOT"
    log_success "Tests completed"
}

# Full deployment
run_deploy() {
    log_info "Starting full deployment..."

    # Phase 1: Bootstrap VPS
    log_info "Phase 1: Bootstrap VPS..."
    run_bootstrap

    # Phase 2: Initialize and apply Terraform
    log_info "Phase 2: Initialize Terraform..."
    run_terraform init

    log_info "Phase 2: Plan Terraform changes..."
    run_terraform plan

    read -rp "Apply Terraform changes? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        run_terraform apply -auto-approve
    else
        log_warn "Terraform apply skipped - cannot continue without VMs"
        return 1
    fi

    # Wait for OPNsense VM to boot
    log_info "Waiting for OPNsense VM to boot (60 seconds)..."
    sleep 60

    # Phase 3: Configure OPNsense
    log_info "Phase 3: Configure OPNsense firewall..."
    read -rp "Configure OPNsense? [y/N] " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        run_opnsense
    else
        log_warn "OPNsense configuration skipped"
    fi

    # Phase 4: Deploy Tailscale (if playbook exists)
    if [[ -f "$PROJECT_ROOT/ansible/playbooks/tailscale.yml" ]]; then
        log_info "Phase 4: Deploy Tailscale VPN..."
        read -rp "Deploy Tailscale? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            run_tailscale
        else
            log_warn "Tailscale deployment skipped"
        fi
    fi

    # Phase 5: Deploy Proxmox (if playbook exists)
    if [[ -f "$PROJECT_ROOT/ansible/playbooks/proxmox.yml" ]]; then
        log_info "Phase 5: Deploy Proxmox VE..."
        read -rp "Deploy Proxmox? [y/N] " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            run_proxmox
        else
            log_warn "Proxmox deployment skipped"
        fi
    fi

    # Run tests
    log_info "Running validation tests..."
    run_tests all || true

    log_success "Full deployment completed"
}

# Destroy infrastructure
run_destroy() {
    log_warn "This will destroy ALL infrastructure!"
    read -rp "Are you sure? Type 'destroy' to confirm: " confirm

    if [[ "$confirm" == "destroy" ]]; then
        run_terraform destroy -auto-approve
        log_success "Infrastructure destroyed"
    else
        log_info "Destroy cancelled"
    fi
}

# Show deployment status
show_status() {
    log_info "Deployment Status"
    echo "=================="

    # Check Terraform state
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        log_info "Terraform state exists"
        cd "$PROJECT_ROOT/terraform"
        terraform show -no-color 2>/dev/null | head -50 || true
        cd "$PROJECT_ROOT"
    else
        log_warn "No Terraform state found"
    fi

    # Check VPS connectivity
    log_info "Checking VPS connectivity..."
    if ansible hypervisors -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m ping 2>/dev/null; then
        log_success "VPS is reachable"
    else
        log_warn "VPS is not reachable"
    fi
}

# Main
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
        bootstrap)
            preflight_checks
            run_bootstrap "$@"
            ;;
        terraform)
            preflight_checks
            run_terraform "$@"
            ;;
        opnsense)
            preflight_checks
            run_opnsense "$@"
            ;;
        tailscale)
            preflight_checks
            run_tailscale "$@"
            ;;
        proxmox)
            preflight_checks
            run_proxmox "$@"
            ;;
        deploy)
            preflight_checks
            validate_config
            run_deploy "$@"
            ;;
        destroy)
            preflight_checks
            run_destroy "$@"
            ;;
        status)
            show_status
            ;;
        validate)
            preflight_checks
            validate_config
            ;;
        test)
            preflight_checks
            run_tests "$@"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
