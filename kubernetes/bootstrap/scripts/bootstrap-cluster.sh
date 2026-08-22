#!/usr/bin/env bash
# bootstrap-cluster.sh - Bootstrap Talos Kubernetes cluster
# Usage: ./bootstrap-cluster.sh [--apply-only] [--bootstrap-only]
#
# Prerequisites:
#   - talosctl installed and configured
#   - Machine configurations generated (run generate-configs.sh first)
#   - VMs created and booted with Talos ISO
#   - Network connectivity to all nodes
#
# This script:
#   1. Applies machine configurations to all control plane nodes
#   2. Bootstraps etcd on the first control plane node
#   3. Waits for cluster to be healthy
#   4. Retrieves kubeconfig for kubectl access

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TALOS_DIR="${PROJECT_ROOT}/bootstrap/talos"
OUTPUT_DIR="${TALOS_DIR}/generated"

# Cluster settings
CLUSTER_ENDPOINT="https://10.9.8.100:6443"
TALOSCONFIG="${OUTPUT_DIR}/talosconfig"

# Node configuration (order matters - first node bootstraps etcd)
declare -a CONTROL_PLANE_ORDER=("talos-cp-1" "talos-cp-2" "talos-cp-3")
declare -A CONTROL_PLANE_NODES=(
    ["talos-cp-1"]="10.9.8.11"
    ["talos-cp-2"]="10.9.8.12"
    ["talos-cp-3"]="10.9.8.13"
)

# Timeouts
APPLY_TIMEOUT="5m"
BOOTSTRAP_TIMEOUT="10m"
HEALTH_TIMEOUT="15m"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v talosctl &>/dev/null; then
        log_error "talosctl not found"
        exit 1
    fi

    if [[ ! -f "${TALOSCONFIG}" ]]; then
        log_error "Talosconfig not found: ${TALOSCONFIG}"
        log_error "Run generate-configs.sh first"
        exit 1
    fi

    # Export talosconfig for all commands
    export TALOSCONFIG

    # Check node configs exist
    for node in "${CONTROL_PLANE_ORDER[@]}"; do
        local config="${OUTPUT_DIR}/${node}.yaml"
        if [[ ! -f "${config}" ]]; then
            log_error "Node config not found: ${config}"
            exit 1
        fi
    done

    log_success "Prerequisites check passed"
}

# Check node connectivity
check_connectivity() {
    log_info "Checking node connectivity..."

    local all_reachable=true
    for node in "${CONTROL_PLANE_ORDER[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        if ping -c 1 -W 2 "${ip}" &>/dev/null; then
            log_success "  ${node} (${ip}): reachable"
        else
            log_warn "  ${node} (${ip}): not reachable"
            all_reachable=false
        fi
    done

    if [[ "${all_reachable}" != "true" ]]; then
        log_warn "Some nodes are not reachable. They may not be booted yet."
        read -p "Continue anyway? (yes/no): " confirm
        if [[ "${confirm}" != "yes" ]]; then
            log_info "Aborted."
            exit 0
        fi
    fi
}

# Apply machine configurations
apply_configs() {
    log_info "Applying machine configurations..."

    for node in "${CONTROL_PLANE_ORDER[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        local config="${OUTPUT_DIR}/${node}.yaml"

        log_info "  Applying config to ${node} (${ip})..."

        # Check if node is in maintenance mode (fresh install)
        local mode
        mode=$(talosctl --nodes "${ip}" get machinestatus -o jsonpath='{.spec.stage}' 2>/dev/null || echo "unknown")

        if [[ "${mode}" == "maintenance" ]]; then
            log_info "    Node in maintenance mode, applying initial config..."
            talosctl apply-config --insecure \
                --nodes "${ip}" \
                --file "${config}" \
                --timeout "${APPLY_TIMEOUT}"
        else
            log_info "    Node already configured, applying update..."
            talosctl apply-config \
                --nodes "${ip}" \
                --file "${config}" \
                --timeout "${APPLY_TIMEOUT}"
        fi

        log_success "  Config applied to ${node}"
    done

    log_success "All configurations applied"
}

# Bootstrap etcd on first control plane node
bootstrap_etcd() {
    local bootstrap_node="${CONTROL_PLANE_ORDER[0]}"
    local bootstrap_ip="${CONTROL_PLANE_NODES[$bootstrap_node]}"

    log_info "Bootstrapping etcd on ${bootstrap_node} (${bootstrap_ip})..."

    # Check if already bootstrapped
    local etcd_status
    etcd_status=$(talosctl --nodes "${bootstrap_ip}" service etcd 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${etcd_status}" -gt 0 ]]; then
        log_info "etcd already running on ${bootstrap_node}"
        return 0
    fi

    # Wait for node to be ready for bootstrap
    log_info "Waiting for ${bootstrap_node} to be ready..."
    local retries=30
    while [[ ${retries} -gt 0 ]]; do
        local stage
        stage=$(talosctl --nodes "${bootstrap_ip}" get machinestatus -o jsonpath='{.spec.stage}' 2>/dev/null || echo "unknown")

        if [[ "${stage}" == "booting" ]] || [[ "${stage}" == "running" ]]; then
            break
        fi

        log_info "  Current stage: ${stage}, waiting..."
        sleep 10
        ((retries--))
    done

    if [[ ${retries} -eq 0 ]]; then
        log_error "Timeout waiting for ${bootstrap_node} to be ready"
        exit 1
    fi

    # Bootstrap etcd
    log_info "Initiating etcd bootstrap..."
    talosctl bootstrap --nodes "${bootstrap_ip}" --timeout "${BOOTSTRAP_TIMEOUT}"

    log_success "etcd bootstrap initiated on ${bootstrap_node}"
}

# Wait for cluster health
wait_for_health() {
    log_info "Waiting for cluster to become healthy..."

    local start_time
    start_time=$(date +%s)
    local timeout_seconds=900  # 15 minutes

    while true; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if [[ ${elapsed} -gt ${timeout_seconds} ]]; then
            log_error "Timeout waiting for cluster health"
            exit 1
        fi

        # Check etcd health
        local etcd_healthy=true
        for node in "${CONTROL_PLANE_ORDER[@]}"; do
            local ip="${CONTROL_PLANE_NODES[$node]}"
            local etcd_status
            etcd_status=$(talosctl --nodes "${ip}" service etcd 2>/dev/null | grep -c "Running" || echo "0")

            if [[ "${etcd_status}" -eq 0 ]]; then
                etcd_healthy=false
                break
            fi
        done

        if [[ "${etcd_healthy}" == "true" ]]; then
            log_success "etcd is healthy on all control plane nodes"
            break
        fi

        log_info "  Waiting for etcd... (${elapsed}s elapsed)"
        sleep 15
    done

    # Wait for Kubernetes API
    log_info "Waiting for Kubernetes API..."
    local retries=60
    while [[ ${retries} -gt 0 ]]; do
        if talosctl --nodes "${CONTROL_PLANE_NODES[talos-cp-1]}" health --wait-timeout 30s 2>/dev/null; then
            log_success "Cluster is healthy!"
            return 0
        fi
        log_info "  Still waiting for Kubernetes API..."
        sleep 10
        ((retries--))
    done

    log_error "Timeout waiting for Kubernetes API"
    exit 1
}

# Retrieve kubeconfig
get_kubeconfig() {
    local kubeconfig_file="${PROJECT_ROOT}/kubeconfig"

    log_info "Retrieving kubeconfig..."

    talosctl kubeconfig "${kubeconfig_file}" \
        --nodes "${CONTROL_PLANE_NODES[talos-cp-1]}" \
        --force

    chmod 600 "${kubeconfig_file}"

    log_success "Kubeconfig saved to: ${kubeconfig_file}"
    log_warn "⚠️  Do not commit kubeconfig to git!"

    echo ""
    log_info "To use kubectl:"
    echo "  export KUBECONFIG=${kubeconfig_file}"
    echo "  kubectl get nodes"
}

# Print cluster status
print_status() {
    echo ""
    echo "======================================"
    echo "Cluster Bootstrap Complete"
    echo "======================================"
    echo ""

    log_info "Cluster endpoint: ${CLUSTER_ENDPOINT}"
    echo ""

    log_info "Control Plane Nodes:"
    for node in "${CONTROL_PLANE_ORDER[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        echo "  ${node}: ${ip}"
    done
    echo ""

    log_info "Next steps:"
    echo "  1. Set KUBECONFIG: export KUBECONFIG=${PROJECT_ROOT}/kubeconfig"
    echo "  2. Verify nodes: kubectl get nodes"
    echo "  3. Install Cilium CNI: ./install-cilium.sh"
    echo "  4. Verify cluster health: ./verify-cluster.sh"
    echo ""
}

# Main
main() {
    echo "======================================"
    echo "Talos Cluster Bootstrap"
    echo "======================================"
    echo ""

    # Parse arguments
    APPLY_ONLY=false
    BOOTSTRAP_ONLY=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --apply-only)
                APPLY_ONLY=true
                shift
                ;;
            --bootstrap-only)
                BOOTSTRAP_ONLY=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--apply-only] [--bootstrap-only]"
                echo ""
                echo "Options:"
                echo "  --apply-only      Only apply configs, skip bootstrap"
                echo "  --bootstrap-only  Only bootstrap etcd, skip config apply"
                echo "  --help, -h        Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites

    if [[ "${BOOTSTRAP_ONLY}" != "true" ]]; then
        check_connectivity
        apply_configs
    fi

    if [[ "${APPLY_ONLY}" != "true" ]]; then
        bootstrap_etcd
        wait_for_health
        get_kubeconfig
    fi

    print_status
}

main "$@"
