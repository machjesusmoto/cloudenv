#!/usr/bin/env bash
# install-cilium.sh - Install Cilium CNI on Talos Kubernetes cluster
# Usage: ./install-cilium.sh [--dry-run]
#
# Prerequisites:
#   - Kubernetes cluster bootstrapped (run bootstrap-cluster.sh first)
#   - kubectl configured with cluster access
#   - helm v3 installed
#
# This script:
#   1. Adds Cilium Helm repository
#   2. Installs Cilium with Talos-optimized values
#   3. Waits for Cilium to be healthy
#   4. Validates cluster networking

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
VALUES_FILE="${PROJECT_ROOT}/core/networking/cilium/values.yaml"

# Cilium settings
CILIUM_VERSION="1.16.4"
CILIUM_NAMESPACE="kube-system"

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

    # Check kubectl
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found"
        exit 1
    fi

    # Check helm
    if ! command -v helm &>/dev/null; then
        log_error "helm not found. Install from: https://helm.sh/docs/intro/install/"
        exit 1
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        log_error "Ensure KUBECONFIG is set: export KUBECONFIG=${PROJECT_ROOT}/kubeconfig"
        exit 1
    fi

    # Check values file
    if [[ ! -f "${VALUES_FILE}" ]]; then
        log_error "Values file not found: ${VALUES_FILE}"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Add Cilium Helm repository
add_helm_repo() {
    log_info "Adding Cilium Helm repository..."

    helm repo add cilium https://helm.cilium.io/ 2>/dev/null || true
    helm repo update

    log_success "Helm repository configured"
}

# Install Cilium
install_cilium() {
    log_info "Installing Cilium ${CILIUM_VERSION}..."

    local helm_args=(
        upgrade --install cilium cilium/cilium
        --version "${CILIUM_VERSION}"
        --namespace "${CILIUM_NAMESPACE}"
        --values "${VALUES_FILE}"
        --wait
        --timeout 10m
    )

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        helm_args+=(--dry-run)
        log_info "Dry run mode - not actually installing"
    fi

    helm "${helm_args[@]}"

    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        log_success "Cilium installed successfully"
    fi
}

# Wait for Cilium to be ready
wait_for_cilium() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Dry run - skipping health check"
        return 0
    fi

    log_info "Waiting for Cilium pods to be ready..."

    # Wait for Cilium daemonset
    kubectl rollout status daemonset/cilium \
        --namespace "${CILIUM_NAMESPACE}" \
        --timeout=5m

    # Wait for Cilium operator
    kubectl rollout status deployment/cilium-operator \
        --namespace "${CILIUM_NAMESPACE}" \
        --timeout=5m

    log_success "Cilium pods are ready"
}

# Validate Cilium installation
validate_cilium() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Dry run - skipping validation"
        return 0
    fi

    log_info "Validating Cilium installation..."

    # Check Cilium status
    log_info "Checking Cilium agent status..."
    kubectl exec -n "${CILIUM_NAMESPACE}" \
        -l k8s-app=cilium \
        -c cilium-agent \
        -- cilium status --brief || {
            log_warn "Cilium status check failed, waiting..."
            sleep 30
            kubectl exec -n "${CILIUM_NAMESPACE}" \
                -l k8s-app=cilium \
                -c cilium-agent \
                -- cilium status --brief
        }

    # Check nodes are ready
    log_info "Checking node status..."
    kubectl get nodes -o wide

    # Check pods running
    log_info "Checking Cilium pods..."
    kubectl get pods -n "${CILIUM_NAMESPACE}" -l k8s-app=cilium

    log_success "Cilium validation complete"
}

# Print status
print_status() {
    echo ""
    echo "======================================"
    echo "Cilium Installation Complete"
    echo "======================================"
    echo ""

    log_info "Cilium Version: ${CILIUM_VERSION}"
    log_info "Namespace: ${CILIUM_NAMESPACE}"
    echo ""

    if [[ "${DRY_RUN:-false}" != "true" ]]; then
        log_info "Useful commands:"
        echo "  # Check Cilium status"
        echo "  kubectl exec -n kube-system -l k8s-app=cilium -c cilium-agent -- cilium status"
        echo ""
        echo "  # View Cilium connectivity"
        echo "  kubectl exec -n kube-system -l k8s-app=cilium -c cilium-agent -- cilium-health status"
        echo ""
        echo "  # Access Hubble UI (if enabled)"
        echo "  kubectl port-forward -n kube-system svc/hubble-ui 12000:80"
        echo ""
    fi

    log_info "Next steps:"
    echo "  1. Verify nodes are Ready: kubectl get nodes"
    echo "  2. Deploy test workload: kubectl run test --image=nginx"
    echo "  3. Run smoke tests: ./verify-cluster.sh"
    echo ""
}

# Main
main() {
    echo "======================================"
    echo "Cilium CNI Installation"
    echo "======================================"
    echo ""

    # Parse arguments
    DRY_RUN=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--dry-run]"
                echo ""
                echo "Options:"
                echo "  --dry-run    Show what would be installed without making changes"
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
    add_helm_repo
    install_cilium
    wait_for_cilium
    validate_cilium
    print_status
}

main "$@"
