#!/usr/bin/env bash
# argocd-test.sh - Validate ArgoCD installation and functionality
# Usage: ./argocd-test.sh [--cleanup]
#
# This script validates:
#   1. ArgoCD namespace exists
#   2. ArgoCD components are running
#   3. ArgoCD server is accessible
#   4. Admin credentials can be retrieved
#   5. App-of-apps Application exists and is healthy
#   6. (Optional) Test Application sync functionality
#
# Creates temporary resources that are cleaned up after testing

set -euo pipefail

# Configuration
ARGOCD_NAMESPACE="argocd"
TIMEOUT=120

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
    kubectl delete application test-app -n "${ARGOCD_NAMESPACE}" --ignore-not-found=true 2>/dev/null || true
}

# Test ArgoCD namespace
test_namespace() {
    log_section "ArgoCD Namespace"

    if kubectl get namespace "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_pass "ArgoCD namespace exists"
    else
        log_fail "ArgoCD namespace not found"
        return 1
    fi
}

# Test ArgoCD components
test_components() {
    log_section "ArgoCD Components"

    local components=(
        "deployment/argocd-server"
        "deployment/argocd-repo-server"
        "deployment/argocd-applicationset-controller"
        "deployment/argocd-redis"
        "statefulset/argocd-application-controller"
    )

    for component in "${components[@]}"; do
        local name
        name=$(echo "${component}" | cut -d'/' -f2)

        if kubectl get "${component}" -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
            local ready
            if [[ "${component}" == deployment/* ]]; then
                ready=$(kubectl get "${component}" -n "${ARGOCD_NAMESPACE}" \
                    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            else
                ready=$(kubectl get "${component}" -n "${ARGOCD_NAMESPACE}" \
                    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            fi

            if [[ "${ready}" -ge 1 ]]; then
                log_pass "${name} is running (${ready} ready)"
            else
                log_fail "${name} is not ready (${ready:-0} ready)"
            fi
        else
            log_fail "${name} not found"
        fi
    done
}

# Test ArgoCD server accessibility
test_server_access() {
    log_section "ArgoCD Server Access"

    # Check service exists
    if kubectl get svc argocd-server -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_pass "ArgoCD server service exists"
    else
        log_fail "ArgoCD server service not found"
        return 1
    fi

    # Get service type
    local svc_type
    svc_type=$(kubectl get svc argocd-server -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.spec.type}')
    log_info "Service type: ${svc_type}"

    # Get endpoints
    local endpoints
    endpoints=$(kubectl get endpoints argocd-server -n "${ARGOCD_NAMESPACE}" \
        -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null || echo "")

    if [[ -n "${endpoints}" ]]; then
        log_pass "ArgoCD server has endpoints: ${endpoints}"
    else
        log_fail "ArgoCD server has no endpoints"
    fi
}

# Test admin credentials
test_admin_credentials() {
    log_section "Admin Credentials"

    local password
    password=$(kubectl -n "${ARGOCD_NAMESPACE}" get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d || echo "")

    if [[ -n "${password}" ]]; then
        log_pass "Initial admin password is available"
        log_info "Password length: ${#password} characters"
    else
        log_warn "Initial admin secret not found (may have been changed/deleted)"
    fi
}

# Test ArgoCD CRDs
test_crds() {
    log_section "ArgoCD CRDs"

    local crds=(
        "applications.argoproj.io"
        "applicationsets.argoproj.io"
        "appprojects.argoproj.io"
    )

    for crd in "${crds[@]}"; do
        if kubectl get crd "${crd}" &>/dev/null; then
            log_pass "CRD ${crd} exists"
        else
            log_fail "CRD ${crd} not found"
        fi
    done
}

# Test app-of-apps Application
test_app_of_apps() {
    log_section "App-of-Apps Application"

    if kubectl get application app-of-apps -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_pass "app-of-apps Application exists"

        # Check sync status
        local health
        local sync
        health=$(kubectl get application app-of-apps -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        sync=$(kubectl get application app-of-apps -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")

        log_info "Health: ${health}"
        log_info "Sync: ${sync}"

        if [[ "${health}" == "Healthy" ]]; then
            log_pass "app-of-apps is Healthy"
        else
            log_warn "app-of-apps health: ${health}"
        fi

        if [[ "${sync}" == "Synced" ]]; then
            log_pass "app-of-apps is Synced"
        else
            log_warn "app-of-apps sync: ${sync}"
        fi
    else
        log_warn "app-of-apps Application not found (may not be applied yet)"
    fi
}

# Test creating a simple Application
test_application_create() {
    log_section "Application Creation Test"

    log_info "Creating test Application..."

    kubectl apply -f - <<EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app
  namespace: ${ARGOCD_NAMESPACE}
spec:
  project: default
  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook
  destination:
    server: https://kubernetes.default.svc
    namespace: default
EOF

    # Wait for Application to be created
    sleep 5

    if kubectl get application test-app -n "${ARGOCD_NAMESPACE}" &>/dev/null; then
        log_pass "Test Application created successfully"

        # Check if Application is recognized
        local status
        status=$(kubectl get application test-app -n "${ARGOCD_NAMESPACE}" \
            -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        log_info "Test Application sync status: ${status}"

        if [[ "${status}" != "Unknown" && "${status}" != "" ]]; then
            log_pass "ArgoCD is processing Applications"
        else
            log_warn "ArgoCD hasn't processed test Application yet"
        fi

        # Cleanup
        log_info "Cleaning up test Application..."
        kubectl delete application test-app -n "${ARGOCD_NAMESPACE}" --wait=false
    else
        log_fail "Failed to create test Application"
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
        echo -e "${GREEN}✓ All ArgoCD tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "ArgoCD Smoke Tests"
    echo "======================================"
    echo ""

    # Parse arguments
    CLEANUP_ONLY=false
    SKIP_APP_TEST=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --cleanup)
                CLEANUP_ONLY=true
                shift
                ;;
            --skip-app-test)
                SKIP_APP_TEST=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--cleanup] [--skip-app-test]"
                echo ""
                echo "Options:"
                echo "  --cleanup         Only cleanup test resources"
                echo "  --skip-app-test   Skip Application creation test"
                echo "  --help, -h        Show this help message"
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

    # Run tests
    test_namespace
    test_crds
    test_components
    test_server_access
    test_admin_credentials
    test_app_of_apps

    if [[ "${SKIP_APP_TEST}" != "true" ]]; then
        test_application_create
    fi

    print_summary
    local result=$?

    exit ${result}
}

main "$@"
