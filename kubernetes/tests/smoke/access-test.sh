#!/usr/bin/env bash
# access-test.sh - Validate cluster access from Tailscale-connected device
# Usage: ./access-test.sh
#
# This script validates:
#   1. Tailscale connectivity to cluster subnet
#   2. Talos API accessibility via VIP
#   3. Kubernetes API accessibility via VIP
#   4. kubectl commands work correctly
#   5. talosctl commands work correctly
#   6. ArgoCD access (via port-forward test)
#
# Should be run from a Tailscale-connected device

set -euo pipefail

# Configuration
TALOS_VIP="10.9.8.100"
TALOS_NODES=("10.9.8.11" "10.9.8.12" "10.9.8.13")
K8S_API_PORT="6443"
TALOS_API_PORT="50000"

# Test results
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_section() { echo -e "\n${CYAN}=== $* ===${NC}"; }

# Check prerequisites
check_prerequisites() {
    log_section "Prerequisites Check"

    local missing=0

    # Check for required tools
    for tool in kubectl talosctl curl ping; do
        if command -v "${tool}" &>/dev/null; then
            log_info "${tool}: available"
        else
            log_warn "${tool}: not found"
            if [[ "${tool}" == "kubectl" || "${tool}" == "talosctl" ]]; then
                missing=1
            fi
        fi
    done

    # Check Tailscale
    if command -v tailscale &>/dev/null; then
        local ts_status
        ts_status=$(tailscale status --json 2>/dev/null | jq -r '.Self.Online' 2>/dev/null || echo "false")
        if [[ "${ts_status}" == "true" ]]; then
            log_pass "Tailscale is online"
        else
            log_warn "Tailscale may not be connected"
        fi
    else
        log_warn "Tailscale CLI not found - skipping status check"
    fi

    if [[ ${missing} -eq 1 ]]; then
        log_fail "Required tools missing"
        return 1
    fi

    log_pass "Prerequisites check passed"
}

# Test network connectivity
test_network_connectivity() {
    log_section "Network Connectivity"

    # Test VIP
    log_info "Testing VIP connectivity..."
    if ping -c 1 -W 5 "${TALOS_VIP}" &>/dev/null; then
        log_pass "VIP ${TALOS_VIP} is reachable"
    else
        log_fail "VIP ${TALOS_VIP} is not reachable"
    fi

    # Test individual nodes
    for node in "${TALOS_NODES[@]}"; do
        if ping -c 1 -W 5 "${node}" &>/dev/null; then
            log_pass "Node ${node} is reachable"
        else
            log_warn "Node ${node} is not reachable"
        fi
    done
}

# Test Talos API
test_talos_api() {
    log_section "Talos API Access"

    # Test VIP
    log_info "Testing Talos API via VIP..."
    if curl -sk --connect-timeout 5 "https://${TALOS_VIP}:${TALOS_API_PORT}/version" &>/dev/null; then
        log_pass "Talos API reachable via VIP"
    else
        log_warn "Talos API not reachable via VIP (may require client cert)"
    fi

    # Test with talosctl
    if command -v talosctl &>/dev/null; then
        log_info "Testing talosctl version..."
        if talosctl version --nodes "${TALOS_VIP}" &>/dev/null; then
            log_pass "talosctl can connect to cluster"

            # Get cluster version
            local version
            version=$(talosctl version --nodes "${TALOS_VIP}" 2>/dev/null | grep "Tag:" | head -1 | awk '{print $2}')
            log_info "Talos version: ${version:-unknown}"
        else
            log_fail "talosctl cannot connect to cluster"
        fi

        # Test health check
        log_info "Testing talosctl health..."
        if talosctl health --nodes "${TALOS_VIP}" &>/dev/null; then
            log_pass "Talos cluster is healthy"
        else
            log_warn "Talos health check failed (may need more time)"
        fi
    fi
}

# Test Kubernetes API
test_kubernetes_api() {
    log_section "Kubernetes API Access"

    # Test with curl
    log_info "Testing Kubernetes API via VIP..."
    if curl -sk --connect-timeout 5 "https://${TALOS_VIP}:${K8S_API_PORT}/healthz" | grep -q "ok"; then
        log_pass "Kubernetes API is healthy"
    else
        log_warn "Kubernetes API health check inconclusive"
    fi

    # Test with kubectl
    if command -v kubectl &>/dev/null; then
        log_info "Testing kubectl cluster-info..."
        if kubectl cluster-info &>/dev/null; then
            log_pass "kubectl can connect to cluster"

            # Get cluster info
            local k8s_version
            k8s_version=$(kubectl version -o json 2>/dev/null | jq -r '.serverVersion.gitVersion' 2>/dev/null || echo "unknown")
            log_info "Kubernetes version: ${k8s_version}"
        else
            log_fail "kubectl cannot connect to cluster"
            return 1
        fi

        # Test node listing
        log_info "Testing kubectl get nodes..."
        local node_count
        node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
        if [[ "${node_count}" -ge 1 ]]; then
            log_pass "kubectl get nodes: ${node_count} nodes found"
            kubectl get nodes 2>/dev/null | head -10
        else
            log_fail "No nodes found in cluster"
        fi

        # Test pod listing
        log_info "Testing kubectl get pods..."
        local pod_count
        pod_count=$(kubectl get pods -A --no-headers 2>/dev/null | wc -l)
        log_info "Total pods in cluster: ${pod_count}"
    fi
}

# Test Talos operations
test_talos_operations() {
    log_section "Talos Operations"

    if ! command -v talosctl &>/dev/null; then
        log_warn "talosctl not installed - skipping operations tests"
        return 0
    fi

    # Test etcd status
    log_info "Testing etcd status..."
    if talosctl etcd status --nodes "${TALOS_VIP}" &>/dev/null; then
        log_pass "etcd cluster status accessible"

        # Show etcd members
        talosctl etcd status --nodes "${TALOS_VIP}" 2>/dev/null | head -10
    else
        log_warn "etcd status check failed"
    fi

    # Test member list
    log_info "Testing member list..."
    if talosctl get members --nodes "${TALOS_VIP}" &>/dev/null; then
        log_pass "Cluster members accessible"

        local member_count
        member_count=$(talosctl get members --nodes "${TALOS_VIP}" 2>/dev/null | grep -c "Member" || echo "0")
        log_info "Cluster members: ${member_count}"
    else
        log_warn "Member list failed"
    fi
}

# Test kubectl operations
test_kubectl_operations() {
    log_section "Kubernetes Operations"

    if ! command -v kubectl &>/dev/null; then
        log_warn "kubectl not installed - skipping operations tests"
        return 0
    fi

    # Test namespace listing
    log_info "Testing namespace access..."
    if kubectl get namespaces &>/dev/null; then
        log_pass "Namespace listing works"
    else
        log_fail "Cannot list namespaces"
    fi

    # Test pod exec capability
    log_info "Testing pod access..."
    local test_pod
    test_pod=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [[ -n "${test_pod}" ]]; then
        if kubectl exec -n kube-system "${test_pod}" -- cilium version &>/dev/null; then
            log_pass "Pod exec works (tested on Cilium pod)"
        else
            log_warn "Pod exec may be restricted"
        fi
    else
        log_info "No Cilium pods found for exec test"
    fi

    # Test logs access
    log_info "Testing log access..."
    if kubectl logs -n kube-system -l component=kube-apiserver --tail=1 &>/dev/null; then
        log_pass "Log access works"
    else
        log_warn "Log access may be restricted"
    fi
}

# Test ArgoCD access
test_argocd_access() {
    log_section "ArgoCD Access"

    # Check if ArgoCD is installed
    if ! kubectl get namespace argocd &>/dev/null; then
        log_info "ArgoCD namespace not found - skipping ArgoCD tests"
        return 0
    fi

    # Check ArgoCD server
    log_info "Checking ArgoCD server..."
    if kubectl get svc argocd-server -n argocd &>/dev/null; then
        log_pass "ArgoCD server service exists"

        # Get service details
        local svc_type
        svc_type=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.type}')
        log_info "ArgoCD service type: ${svc_type}"

        if [[ "${svc_type}" == "NodePort" ]]; then
            local node_port
            node_port=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[0].nodePort}')
            log_info "ArgoCD NodePort: ${node_port}"
            log_info "Access via: https://${TALOS_VIP}:${node_port}"
        else
            log_info "Access via: kubectl port-forward svc/argocd-server -n argocd 8080:443"
        fi
    else
        log_warn "ArgoCD server not found"
    fi

    # Check for admin password
    if kubectl get secret argocd-initial-admin-secret -n argocd &>/dev/null; then
        log_pass "ArgoCD admin secret exists"
    else
        log_info "ArgoCD admin secret not found (may have been deleted)"
    fi
}

# Print summary
print_summary() {
    log_section "Access Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  Total:   ${total}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ All access tests passed!${NC}"
        echo ""
        echo "Remote access is fully operational."
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        echo ""
        echo "Check ACCESS.md for troubleshooting guidance."
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Cluster Access Tests"
    echo "======================================"
    echo ""
    echo "Testing access from: $(hostname)"
    echo "Target VIP: ${TALOS_VIP}"
    echo ""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                echo "Usage: $0 [--vip VIP_ADDRESS]"
                echo ""
                echo "Options:"
                echo "  --vip VIP_ADDRESS   Override default VIP (default: ${TALOS_VIP})"
                echo "  --help, -h          Show this help message"
                exit 0
                ;;
            --vip)
                TALOS_VIP="$2"
                shift 2
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    test_network_connectivity
    test_talos_api
    test_kubernetes_api
    test_talos_operations
    test_kubectl_operations
    test_argocd_access

    print_summary
    local result=$?

    exit ${result}
}

main "$@"
