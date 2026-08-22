#!/usr/bin/env bash
# generate-configs.sh - Generate Talos machine configurations
# Usage: ./generate-configs.sh [--force]
#
# Prerequisites:
#   - talosctl installed (https://www.talos.dev/v1.9/introduction/getting-started/)
#   - Age key for SOPS encryption (optional, for secrets)
#
# This script generates:
#   - Talos secrets (secrets.yaml) - KEEP SECURE, NEVER COMMIT
#   - Control plane configurations with node-specific patches
#   - Talosconfig for cluster management

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TALOS_DIR="${PROJECT_ROOT}/bootstrap/talos"
OUTPUT_DIR="${TALOS_DIR}/generated"
PATCHES_DIR="${TALOS_DIR}/patches"

# Cluster settings
CLUSTER_NAME="cloudenv-k8s"
CLUSTER_ENDPOINT="https://10.9.8.100:6443"  # Talos VIP
TALOS_VERSION="v1.9.1"
KUBERNETES_VERSION="v1.31.4"

# Node configuration
declare -A CONTROL_PLANE_NODES=(
    ["talos-cp-1"]="10.9.8.11"
    ["talos-cp-2"]="10.9.8.12"
    ["talos-cp-3"]="10.9.8.13"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v talosctl &>/dev/null; then
        log_error "talosctl not found. Install from: https://www.talos.dev/v1.9/introduction/getting-started/"
        exit 1
    fi

    local version
    version=$(talosctl version --client --short 2>/dev/null || echo "unknown")
    log_info "talosctl version: ${version}"

    log_success "Prerequisites check passed"
}

# Generate or load secrets
generate_secrets() {
    local secrets_file="${TALOS_DIR}/secrets.yaml"

    if [[ -f "${secrets_file}" ]]; then
        if [[ "${FORCE:-false}" == "true" ]]; then
            log_warn "Force flag set, regenerating secrets..."
            log_warn "⚠️  This will invalidate existing cluster configurations!"
            read -p "Are you sure? (yes/no): " confirm
            if [[ "${confirm}" != "yes" ]]; then
                log_info "Aborted."
                exit 0
            fi
        else
            log_info "Using existing secrets.yaml"
            log_warn "Use --force to regenerate (will invalidate existing configs)"
            return 0
        fi
    fi

    log_info "Generating new cluster secrets..."
    talosctl gen secrets -o "${secrets_file}"
    chmod 600 "${secrets_file}"

    log_success "Secrets generated: ${secrets_file}"
    log_warn "⚠️  CRITICAL: Back up secrets.yaml securely! Never commit to git!"
}

# Generate machine configurations
generate_configs() {
    log_info "Creating output directory: ${OUTPUT_DIR}"
    mkdir -p "${OUTPUT_DIR}"

    local secrets_file="${TALOS_DIR}/secrets.yaml"
    local common_patch="${PATCHES_DIR}/common.yaml"

    # Verify required files exist
    if [[ ! -f "${secrets_file}" ]]; then
        log_error "secrets.yaml not found. Run this script first to generate."
        exit 1
    fi

    if [[ ! -f "${common_patch}" ]]; then
        log_error "Common patch not found: ${common_patch}"
        exit 1
    fi

    log_info "Generating base configuration..."

    # Generate base configs with common patches
    talosctl gen config "${CLUSTER_NAME}" "${CLUSTER_ENDPOINT}" \
        --with-secrets "${secrets_file}" \
        --config-patch "@${common_patch}" \
        --output-dir "${OUTPUT_DIR}" \
        --force

    log_success "Base configuration generated"

    # Generate node-specific configurations
    log_info "Generating node-specific configurations..."

    for node in "${!CONTROL_PLANE_NODES[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        local node_patch="${PATCHES_DIR}/${node}.yaml"
        local output_file="${OUTPUT_DIR}/${node}.yaml"

        if [[ ! -f "${node_patch}" ]]; then
            log_warn "Node patch not found: ${node_patch}, skipping..."
            continue
        fi

        log_info "  Generating config for ${node} (${ip})..."

        # Merge base controlplane config with node-specific patch
        talosctl machineconfig patch "${OUTPUT_DIR}/controlplane.yaml" \
            --patch "@${node_patch}" \
            --output "${output_file}"

        log_success "  Generated: ${output_file}"
    done

    # Set secure permissions
    chmod 600 "${OUTPUT_DIR}"/*.yaml

    log_success "All configurations generated in: ${OUTPUT_DIR}"
}

# Generate talosconfig for management
setup_talosconfig() {
    local talosconfig="${OUTPUT_DIR}/talosconfig"

    if [[ -f "${talosconfig}" ]]; then
        log_info "Talosconfig already exists: ${talosconfig}"

        # Add node endpoints
        log_info "Adding node endpoints to talosconfig..."
        for node in "${!CONTROL_PLANE_NODES[@]}"; do
            local ip="${CONTROL_PLANE_NODES[$node]}"
            talosctl config endpoint "${ip}" --talosconfig "${talosconfig}" 2>/dev/null || true
        done

        # Set default node
        talosctl config node 10.9.8.11 --talosconfig "${talosconfig}" 2>/dev/null || true

        log_success "Talosconfig configured"
        echo ""
        log_info "To use this config:"
        echo "  export TALOSCONFIG=${talosconfig}"
        echo "  # OR"
        echo "  cp ${talosconfig} ~/.talos/config"
    fi
}

# Print summary
print_summary() {
    echo ""
    echo "======================================"
    echo "Configuration Generation Complete"
    echo "======================================"
    echo ""
    echo "Generated files:"
    echo "  Secrets:      ${TALOS_DIR}/secrets.yaml (KEEP SECURE!)"
    echo "  Talosconfig:  ${OUTPUT_DIR}/talosconfig"
    echo "  Base configs: ${OUTPUT_DIR}/controlplane.yaml"
    echo "                ${OUTPUT_DIR}/worker.yaml"
    echo ""
    echo "Node-specific configs:"
    for node in "${!CONTROL_PLANE_NODES[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        echo "  ${node}: ${OUTPUT_DIR}/${node}.yaml (${ip})"
    done
    echo ""
    echo "Next steps:"
    echo "  1. Back up secrets.yaml to a secure location"
    echo "  2. Create VMs in Proxmox (see VM-SETUP.md)"
    echo "  3. Boot VMs with Talos ISO"
    echo "  4. Run: ./bootstrap-cluster.sh"
    echo ""
}

# Main
main() {
    echo "======================================"
    echo "Talos Configuration Generator"
    echo "======================================"
    echo ""

    # Parse arguments
    FORCE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force|-f)
                FORCE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--force]"
                echo ""
                echo "Options:"
                echo "  --force, -f  Regenerate secrets (will invalidate existing configs)"
                echo "  --help, -h   Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    generate_secrets
    generate_configs
    setup_talosconfig
    print_summary
}

main "$@"
