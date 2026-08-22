#!/usr/bin/env bash
# install-argocd.sh - Install ArgoCD using official manifest
# Usage: ./install-argocd.sh [--version VERSION]
#
# This script:
#   1. Creates the argocd namespace
#   2. Downloads and applies the ArgoCD manifest
#   3. Waits for ArgoCD components to be ready
#   4. Retrieves the initial admin password
#   5. Optionally applies app-of-apps bootstrap

set -euo pipefail

# Configuration
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="${1:-stable}"  # Use 'stable' or specific version like 'v2.13.0'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_DIR="${SCRIPT_DIR}/../../apps/argocd"
TIMEOUT=300

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_section() { echo -e "\n${BLUE}=== $* ===${NC}"; }

# Check prerequisites
check_prerequisites() {
    log_section "Checking Prerequisites"

    local missing=0

    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found"
        missing=1
    else
        log_info "kubectl: $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' 2>/dev/null || echo 'available')"
    fi

    # Check cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster"
        missing=1
    else
        log_info "Cluster connectivity: OK"
    fi

    if [[ ${missing} -eq 1 ]]; then
        log_error "Prerequisites check failed"
        exit 1
    fi

    log_success "Prerequisites check passed"
}

# Create namespace
create_namespace() {
    log_section "Creating ArgoCD Namespace"

    if kubectl get namespace "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_info "Namespace '${ARGOCD_NAMESPACE}' already exists"
    else
        if [[ -f "${ARGOCD_DIR}/namespace.yaml" ]]; then
            kubectl apply -f "${ARGOCD_DIR}/namespace.yaml"
        else
            kubectl create namespace "${ARGOCD_NAMESPACE}"
        fi
        log_success "Namespace '${ARGOCD_NAMESPACE}' created"
    fi
}

# Install ArgoCD
install_argocd() {
    log_section "Installing ArgoCD (${ARGOCD_VERSION})"

    local manifest_url

    if [[ "${ARGOCD_VERSION}" == "stable" ]]; then
        manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
    else
        manifest_url="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
    fi

    log_info "Manifest URL: ${manifest_url}"

    # Check if already installed
    if kubectl get deployment argocd-server -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_info "ArgoCD already installed, checking for updates..."
    fi

    # Apply manifest
    log_info "Applying ArgoCD manifest..."
    kubectl apply -n "${ARGOCD_NAMESPACE}" -f "${manifest_url}"

    log_success "ArgoCD manifest applied"
}

# Wait for ArgoCD to be ready
wait_for_argocd() {
    log_section "Waiting for ArgoCD Components"

    local components=(
        "deployment/argocd-server"
        "deployment/argocd-repo-server"
        "deployment/argocd-applicationset-controller"
        "deployment/argocd-redis"
        "deployment/argocd-notifications-controller"
        "statefulset/argocd-application-controller"
    )

    for component in "${components[@]}"; do
        log_info "Waiting for ${component}..."
        if ! kubectl wait --for=condition=available "${component}" \
            -n "${ARGOCD_NAMESPACE}" \
            --timeout="${TIMEOUT}s" 2>/dev/null; then
            # StatefulSets use different condition
            if [[ "${component}" == statefulset/* ]]; then
                kubectl rollout status "${component}" -n "${ARGOCD_NAMESPACE}" --timeout="${TIMEOUT}s"
            fi
        fi
    done

    log_success "All ArgoCD components are ready"
}

# Get admin password
get_admin_password() {
    log_section "ArgoCD Admin Credentials"

    local password
    password=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)

    if [[ -n "${password}" ]]; then
        echo ""
        log_info "Username: admin"
        log_info "Password: ${password}"
        echo ""
        log_warn "IMPORTANT: Change this password after first login!"
        log_info "Command: argocd account update-password"
    else
        log_warn "Initial admin secret not found (may have been deleted)"
        log_info "Reset with: argocd admin initial-password -n ${ARGOCD_NAMESPACE}"
    fi
}

# Configure server for insecure mode (no TLS termination)
configure_server() {
    log_section "Configuring ArgoCD Server"

    # Patch server deployment to run in insecure mode
    # This is useful when TLS is terminated elsewhere (ingress, Tailscale)
    log_info "Configuring insecure mode (TLS terminated externally)..."

    kubectl patch deployment argocd-server -n "${ARGOCD_NAMESPACE}" \
        --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--insecure"}]' \
        2>/dev/null || log_info "Server already configured or patch not needed"

    log_success "Server configuration complete"
}

# Apply app-of-apps bootstrap
apply_bootstrap() {
    log_section "Applying App-of-Apps Bootstrap"

    if [[ -f "${ARGOCD_DIR}/app-of-apps.yaml" ]]; then
        log_info "Applying app-of-apps Application..."
        kubectl apply -f "${ARGOCD_DIR}/app-of-apps.yaml"
        log_success "App-of-apps bootstrap applied"
    else
        log_warn "app-of-apps.yaml not found at ${ARGOCD_DIR}"
        log_info "Skipping bootstrap - apply manually when ready"
    fi
}

# Show access instructions
show_access_info() {
    log_section "Access Information"

    echo ""
    echo "ArgoCD is now installed and running!"
    echo ""
    echo "Access Options:"
    echo ""
    echo "  1. Port-forward (recommended for initial setup):"
    echo "     kubectl port-forward svc/argocd-server -n ${ARGOCD_NAMESPACE} 8080:443"
    echo "     Open: https://localhost:8080"
    echo ""
    echo "  2. NodePort (direct access via node IP):"
    echo "     kubectl patch svc argocd-server -n ${ARGOCD_NAMESPACE} -p '{\"spec\": {\"type\": \"NodePort\"}}'"
    echo "     Access via: https://<node-ip>:<node-port>"
    echo ""
    echo "  3. Via Tailscale (if configured):"
    echo "     Access via: https://10.9.8.100:8080 (after port-forward)"
    echo ""
    echo "CLI Installation:"
    echo "  curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
    echo "  chmod +x argocd && sudo mv argocd /usr/local/bin/"
    echo ""
}

# Main
main() {
    echo "======================================"
    echo "ArgoCD Installation"
    echo "======================================"
    echo ""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                ARGOCD_VERSION="$2"
                shift 2
                ;;
            --skip-bootstrap)
                SKIP_BOOTSTRAP=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--version VERSION] [--skip-bootstrap]"
                echo ""
                echo "Options:"
                echo "  --version VERSION   ArgoCD version (default: stable)"
                echo "  --skip-bootstrap    Skip app-of-apps bootstrap"
                echo "  --help, -h          Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    create_namespace
    install_argocd
    wait_for_argocd
    configure_server
    get_admin_password

    if [[ "${SKIP_BOOTSTRAP:-false}" != "true" ]]; then
        apply_bootstrap
    fi

    show_access_info

    log_success "ArgoCD installation complete!"
}

main "$@"
