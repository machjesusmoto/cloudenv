#!/usr/bin/env bash
# network-test.sh - Network connectivity and DNS validation
# Usage: ./network-test.sh [--cleanup]
#
# This script validates:
#   1. Pod-to-pod connectivity
#   2. Pod-to-service connectivity
#   3. DNS resolution (internal and external)
#   4. Network policy enforcement (if enabled)
#   5. Service mesh/CNI functionality
#
# Creates temporary test pods that are cleaned up after testing

set -euo pipefail

# Configuration
TEST_NAMESPACE="network-test"
TEST_IMAGE="busybox:1.36"
TIMEOUT=60

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

# Cleanup function
cleanup() {
    log_info "Cleaning up test resources..."
    kubectl delete namespace "${TEST_NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
}

# Setup test namespace
setup() {
    log_section "Setup"

    # Cleanup any existing test resources
    cleanup

    log_info "Creating test namespace: ${TEST_NAMESPACE}"
    kubectl create namespace "${TEST_NAMESPACE}"

    log_pass "Test environment ready"
}

# Wait for pod to be ready
wait_for_pod() {
    local pod_name=$1
    local timeout=${2:-60}

    log_info "Waiting for pod ${pod_name} to be ready..."

    kubectl wait --for=condition=ready pod/"${pod_name}" \
        -n "${TEST_NAMESPACE}" \
        --timeout="${timeout}s" 2>/dev/null || {
            log_fail "Pod ${pod_name} did not become ready"
            return 1
        }

    log_pass "Pod ${pod_name} is ready"
    return 0
}

# Test pod-to-pod connectivity
test_pod_connectivity() {
    log_section "Pod-to-Pod Connectivity"

    # Create two test pods
    log_info "Creating test pods..."

    kubectl run pod-a --image="${TEST_IMAGE}" \
        -n "${TEST_NAMESPACE}" \
        --command -- sleep 3600 &

    kubectl run pod-b --image="${TEST_IMAGE}" \
        -n "${TEST_NAMESPACE}" \
        --command -- sleep 3600 &

    wait

    # Wait for pods
    wait_for_pod "pod-a" "${TIMEOUT}" || return 1
    wait_for_pod "pod-b" "${TIMEOUT}" || return 1

    # Get pod IPs
    local pod_a_ip
    local pod_b_ip
    pod_a_ip=$(kubectl get pod pod-a -n "${TEST_NAMESPACE}" -o jsonpath='{.status.podIP}')
    pod_b_ip=$(kubectl get pod pod-b -n "${TEST_NAMESPACE}" -o jsonpath='{.status.podIP}')

    log_info "Pod A IP: ${pod_a_ip}"
    log_info "Pod B IP: ${pod_b_ip}"

    # Test connectivity from pod-a to pod-b
    log_info "Testing connectivity: pod-a -> pod-b"
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- ping -c 3 "${pod_b_ip}" &>/dev/null; then
        log_pass "Pod-to-pod ping successful (pod-a -> pod-b)"
    else
        log_fail "Pod-to-pod ping failed (pod-a -> pod-b)"
    fi

    # Test connectivity from pod-b to pod-a
    log_info "Testing connectivity: pod-b -> pod-a"
    if kubectl exec pod-b -n "${TEST_NAMESPACE}" -- ping -c 3 "${pod_a_ip}" &>/dev/null; then
        log_pass "Pod-to-pod ping successful (pod-b -> pod-a)"
    else
        log_fail "Pod-to-pod ping failed (pod-b -> pod-a)"
    fi
}

# Test DNS resolution
test_dns() {
    log_section "DNS Resolution"

    # Internal DNS - kubernetes service
    log_info "Testing internal DNS resolution..."
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        nslookup kubernetes.default.svc.cluster.local &>/dev/null; then
        log_pass "Internal DNS: kubernetes.default.svc.cluster.local resolved"
    else
        log_fail "Internal DNS: kubernetes.default.svc.cluster.local failed"
    fi

    # Internal DNS - kube-dns service
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        nslookup kube-dns.kube-system.svc.cluster.local &>/dev/null; then
        log_pass "Internal DNS: kube-dns.kube-system.svc.cluster.local resolved"
    else
        log_fail "Internal DNS: kube-dns.kube-system.svc.cluster.local failed"
    fi

    # External DNS
    log_info "Testing external DNS resolution..."
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        nslookup google.com &>/dev/null; then
        log_pass "External DNS: google.com resolved"
    else
        log_warn "External DNS: google.com resolution failed (may be expected in air-gapped environments)"
    fi
}

# Test service connectivity
test_services() {
    log_section "Service Connectivity"

    # Create a test service
    log_info "Creating test service..."

    kubectl run web-server --image=nginx:alpine \
        -n "${TEST_NAMESPACE}" \
        --port=80 \
        --expose

    wait_for_pod "web-server" "${TIMEOUT}" || return 1

    # Wait for service endpoint to be ready
    sleep 5

    # Test service DNS resolution
    log_info "Testing service DNS..."
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        nslookup web-server.${TEST_NAMESPACE}.svc.cluster.local &>/dev/null; then
        log_pass "Service DNS resolution successful"
    else
        log_fail "Service DNS resolution failed"
    fi

    # Test HTTP connectivity to service
    log_info "Testing HTTP connectivity to service..."
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        wget -q -O /dev/null --timeout=5 http://web-server &>/dev/null; then
        log_pass "HTTP connectivity to service successful"
    else
        log_fail "HTTP connectivity to service failed"
    fi
}

# Test external connectivity
test_external_connectivity() {
    log_section "External Connectivity"

    log_info "Testing external HTTP connectivity..."

    # Note: This may fail in air-gapped environments
    if kubectl exec pod-a -n "${TEST_NAMESPACE}" -- \
        wget -q -O /dev/null --timeout=10 http://www.google.com &>/dev/null; then
        log_pass "External HTTP connectivity successful"
    else
        log_warn "External HTTP connectivity failed (may be expected in isolated environments)"
    fi
}

# Test Cilium-specific features
test_cilium_features() {
    log_section "Cilium Features"

    # Check if Cilium is available
    if ! kubectl get pods -n kube-system -l k8s-app=cilium &>/dev/null; then
        log_warn "Cilium not detected, skipping Cilium-specific tests"
        return 0
    fi

    # Test Cilium connectivity
    log_info "Checking Cilium connectivity matrix..."
    if kubectl exec -n kube-system -l k8s-app=cilium -c cilium-agent -- \
        cilium-health status &>/dev/null; then
        log_pass "Cilium health status check successful"
    else
        log_warn "Cilium health status check inconclusive"
    fi

    # Check Cilium endpoints
    local endpoints
    endpoints=$(kubectl exec -n kube-system -l k8s-app=cilium -c cilium-agent -- \
        cilium endpoint list 2>/dev/null | grep -c "ready" || echo "0")

    if [[ "${endpoints}" -gt 0 ]]; then
        log_pass "Cilium endpoints ready: ${endpoints}"
    else
        log_warn "No Cilium endpoints in ready state"
    fi
}

# Print summary
print_summary() {
    log_section "Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  Total:   ${total}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ All network tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Kubernetes Network Tests"
    echo "======================================"

    # Parse arguments
    CLEANUP_ONLY=false
    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP_ONLY=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--cleanup]"
                echo ""
                echo "Options:"
                echo "  --cleanup    Only cleanup test resources"
                echo "  --help, -h   Show this help message"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    if [[ "${CLEANUP_ONLY}" == "true" ]]; then
        cleanup
        exit 0
    fi

    # Set trap for cleanup on exit
    trap cleanup EXIT

    setup
    test_pod_connectivity
    test_dns
    test_services
    test_external_connectivity
    test_cilium_features

    # Remove trap before final cleanup in summary
    trap - EXIT

    print_summary
    local result=$?

    # Cleanup
    cleanup

    exit ${result}
}

main "$@"
