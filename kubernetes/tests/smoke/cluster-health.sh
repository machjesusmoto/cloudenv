#!/usr/bin/env bash
# cluster-health.sh - Comprehensive cluster health validation
# Usage: ./cluster-health.sh [--verbose]
#
# This script validates:
#   1. Node health and readiness
#   2. Control plane component status
#   3. Cilium CNI functionality
#   4. etcd cluster health
#   5. Talos API responsiveness
#   6. Core system pods
#
# Exit codes:
#   0 - All checks passed
#   1 - One or more checks failed

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Expected cluster configuration
EXPECTED_CONTROL_PLANE_NODES=3
EXPECTED_NODE_COUNT=3  # Control plane only for now
TALOS_VIP="10.9.8.100"

# Control plane node IPs
declare -A CONTROL_PLANE_NODES=(
    ["talos-cp-1"]="10.9.8.11"
    ["talos-cp-2"]="10.9.8.12"
    ["talos-cp-3"]="10.9.8.13"
)

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)); }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; ((TESTS_WARNED++)); }
log_section() { echo -e "\n${CYAN}=== $* ===${NC}"; }

# Check prerequisites
check_prerequisites() {
    log_section "Prerequisites Check"

    # kubectl
    if command -v kubectl &>/dev/null; then
        log_pass "kubectl is installed"
    else
        log_fail "kubectl not found"
        exit 1
    fi

    # Cluster connectivity
    if kubectl cluster-info &>/dev/null; then
        log_pass "Kubernetes API is reachable"
    else
        log_fail "Cannot connect to Kubernetes API"
        exit 1
    fi

    # talosctl (optional but recommended)
    if command -v talosctl &>/dev/null; then
        log_pass "talosctl is installed"
    else
        log_warn "talosctl not found - some checks will be skipped"
    fi
}

# Test node health
test_nodes() {
    log_section "Node Health"

    # Get node count
    local node_count
    node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

    if [[ "${node_count}" -ge "${EXPECTED_NODE_COUNT}" ]]; then
        log_pass "Node count: ${node_count} (expected >= ${EXPECTED_NODE_COUNT})"
    else
        log_fail "Node count: ${node_count} (expected >= ${EXPECTED_NODE_COUNT})"
    fi

    # Check all nodes are Ready
    local not_ready
    not_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -cv "Ready" || echo "0")

    if [[ "${not_ready}" -eq 0 ]]; then
        log_pass "All nodes are Ready"
    else
        log_fail "${not_ready} node(s) not in Ready state"
    fi

    # Check control plane nodes specifically
    for node in "${!CONTROL_PLANE_NODES[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"
        if kubectl get node "${node}" &>/dev/null; then
            local status
            status=$(kubectl get node "${node}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}')
            if [[ "${status}" == "True" ]]; then
                log_pass "Control plane node ${node} (${ip}) is Ready"
            else
                log_fail "Control plane node ${node} (${ip}) is not Ready"
            fi
        else
            log_fail "Control plane node ${node} not found"
        fi
    done

    # Verbose output
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo ""
        kubectl get nodes -o wide
    fi
}

# Test control plane components
test_control_plane() {
    log_section "Control Plane Components"

    # API Server
    if kubectl get --raw /healthz &>/dev/null; then
        log_pass "kube-apiserver is healthy"
    else
        log_fail "kube-apiserver health check failed"
    fi

    # Scheduler
    local scheduler_pods
    scheduler_pods=$(kubectl get pods -n kube-system -l component=kube-scheduler --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "${scheduler_pods}" -ge 1 ]]; then
        log_pass "kube-scheduler is running (${scheduler_pods} instances)"
    else
        log_fail "kube-scheduler not found or not running"
    fi

    # Controller Manager
    local cm_pods
    cm_pods=$(kubectl get pods -n kube-system -l component=kube-controller-manager --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    if [[ "${cm_pods}" -ge 1 ]]; then
        log_pass "kube-controller-manager is running (${cm_pods} instances)"
    else
        log_fail "kube-controller-manager not found or not running"
    fi
}

# Test etcd health
test_etcd() {
    log_section "etcd Cluster"

    # etcd pods
    local etcd_pods
    etcd_pods=$(kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${etcd_pods}" -ge "${EXPECTED_CONTROL_PLANE_NODES}" ]]; then
        log_pass "etcd pods running: ${etcd_pods} (expected >= ${EXPECTED_CONTROL_PLANE_NODES})"
    else
        log_fail "etcd pods: ${etcd_pods} (expected >= ${EXPECTED_CONTROL_PLANE_NODES})"
    fi

    # Check etcd via talosctl if available
    if command -v talosctl &>/dev/null; then
        for node in "${!CONTROL_PLANE_NODES[@]}"; do
            local ip="${CONTROL_PLANE_NODES[$node]}"
            local etcd_status
            etcd_status=$(talosctl --nodes "${ip}" service etcd 2>/dev/null | grep -c "Running" || echo "0")

            if [[ "${etcd_status}" -gt 0 ]]; then
                log_pass "etcd on ${node} (${ip}) is Running"
            else
                log_warn "etcd on ${node} (${ip}) status unknown"
            fi
        done
    fi
}

# Test Cilium CNI
test_cilium() {
    log_section "Cilium CNI"

    # Cilium DaemonSet
    local cilium_pods
    cilium_pods=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${cilium_pods}" -ge "${EXPECTED_NODE_COUNT}" ]]; then
        log_pass "Cilium agents running: ${cilium_pods} (expected >= ${EXPECTED_NODE_COUNT})"
    else
        log_fail "Cilium agents: ${cilium_pods} (expected >= ${EXPECTED_NODE_COUNT})"
    fi

    # Cilium Operator
    local operator_pods
    operator_pods=$(kubectl get pods -n kube-system -l name=cilium-operator --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${operator_pods}" -ge 1 ]]; then
        log_pass "Cilium operator is running"
    else
        log_fail "Cilium operator not running"
    fi

    # Cilium status via exec
    local cilium_status
    if cilium_status=$(kubectl exec -n kube-system -l k8s-app=cilium -c cilium-agent -- cilium status --brief 2>/dev/null); then
        if echo "${cilium_status}" | grep -q "OK"; then
            log_pass "Cilium agent status: OK"
        else
            log_warn "Cilium agent status: degraded"
        fi
    else
        log_warn "Could not query Cilium status"
    fi

    # Hubble (if enabled)
    local hubble_pods
    hubble_pods=$(kubectl get pods -n kube-system -l k8s-app=hubble-relay --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${hubble_pods}" -ge 1 ]]; then
        log_pass "Hubble relay is running"
    else
        log_warn "Hubble relay not running (optional)"
    fi
}

# Test CoreDNS
test_coredns() {
    log_section "CoreDNS"

    local coredns_pods
    coredns_pods=$(kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${coredns_pods}" -ge 2 ]]; then
        log_pass "CoreDNS pods running: ${coredns_pods}"
    elif [[ "${coredns_pods}" -ge 1 ]]; then
        log_warn "CoreDNS pods: ${coredns_pods} (recommend >= 2 for HA)"
    else
        log_fail "CoreDNS not running"
    fi

    # DNS resolution test
    if kubectl run dns-test --image=busybox:1.36 --rm -it --restart=Never \
        --command -- nslookup kubernetes.default.svc.cluster.local &>/dev/null; then
        log_pass "DNS resolution working"
    else
        log_warn "DNS resolution test inconclusive"
    fi 2>/dev/null || true
}

# Test Talos API
test_talos_api() {
    log_section "Talos API"

    if ! command -v talosctl &>/dev/null; then
        log_warn "talosctl not available - skipping Talos API tests"
        return 0
    fi

    # Check VIP
    if ping -c 1 -W 2 "${TALOS_VIP}" &>/dev/null; then
        log_pass "Talos VIP (${TALOS_VIP}) is reachable"
    else
        log_fail "Talos VIP (${TALOS_VIP}) is not reachable"
    fi

    # Check individual nodes
    for node in "${!CONTROL_PLANE_NODES[@]}"; do
        local ip="${CONTROL_PLANE_NODES[$node]}"

        if talosctl --nodes "${ip}" version --short &>/dev/null; then
            log_pass "Talos API on ${node} (${ip}) is responsive"
        else
            log_fail "Talos API on ${node} (${ip}) is not responsive"
        fi
    done
}

# Test system resources
test_resources() {
    log_section "System Resources"

    # Node resource allocation
    for node in "${!CONTROL_PLANE_NODES[@]}"; do
        local allocatable_cpu
        local allocatable_memory

        allocatable_cpu=$(kubectl get node "${node}" -o jsonpath='{.status.allocatable.cpu}' 2>/dev/null || echo "unknown")
        allocatable_memory=$(kubectl get node "${node}" -o jsonpath='{.status.allocatable.memory}' 2>/dev/null || echo "unknown")

        if [[ "${allocatable_cpu}" != "unknown" ]]; then
            log_pass "${node}: CPU ${allocatable_cpu}, Memory ${allocatable_memory}"
        else
            log_warn "${node}: Could not determine resources"
        fi
    done
}

# Print summary
print_summary() {
    log_section "Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED + TESTS_WARNED))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  ${YELLOW}Warned:${NC}  ${TESTS_WARNED}"
    echo -e "  Total:   ${total}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ All critical tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Kubernetes Cluster Health Check"
    echo "======================================"

    # Parse arguments
    VERBOSE=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--verbose]"
                echo ""
                echo "Options:"
                echo "  --verbose, -v  Show detailed output"
                echo "  --help, -h     Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    check_prerequisites
    test_nodes
    test_control_plane
    test_etcd
    test_cilium
    test_coredns
    test_talos_api
    test_resources
    print_summary
}

main "$@"
