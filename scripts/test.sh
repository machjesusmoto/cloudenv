#!/usr/bin/env bash
# T064: CloudEnv Test Runner
# Constitution IV: Test Coverage Discipline
# Runs all validation tests (connectivity + security)

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
NC='\033[0m'

# Counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $*"; ((PASSED_TESTS++)); ((TOTAL_TESTS++)); }
log_fail() { echo -e "${RED}[FAIL]${NC} $*"; ((FAILED_TESTS++)); ((TOTAL_TESTS++)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; ((SKIPPED_TESTS++)); ((TOTAL_TESTS++)); }

usage() {
    cat << EOF
CloudEnv Test Runner

Usage: $(basename "$0") [OPTIONS] [TEST_TYPE]

Test Types:
    all             Run all tests (default)
    security        Run security tests only
    connectivity    Run connectivity tests only
    proxmox         Run Proxmox-specific tests

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    --from-tailnet  Run tests from Tailscale network (enables remote tests)
    --quick         Run quick smoke tests only

Examples:
    $(basename "$0")                    # Run all tests
    $(basename "$0") security           # Security tests only
    $(basename "$0") --from-tailnet     # Run from home network via Tailscale

EOF
}

# Run Ansible test playbook
run_ansible_test() {
    local playbook="$1"
    local name="$2"
    local extra_vars="${3:-}"

    log_info "Running $name tests..."

    if [[ ! -f "$PROJECT_ROOT/ansible/tests/$playbook" ]]; then
        log_skip "$name tests not found: $playbook"
        return 0
    fi

    local cmd="ansible-playbook $PROJECT_ROOT/ansible/tests/$playbook -i $PROJECT_ROOT/ansible/inventory/hosts.yml"

    if [[ -n "$extra_vars" ]]; then
        cmd="$cmd -e '$extra_vars'"
    fi

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        cmd="$cmd -v"
    fi

    if eval "$cmd"; then
        log_success "$name tests passed"
        return 0
    else
        log_fail "$name tests failed"
        return 1
    fi
}

# Run security tests
run_security_tests() {
    log_info "=== Security Tests ==="

    run_ansible_test "security.yml" "Firewall Security"
}

# Run connectivity tests
run_connectivity_tests() {
    local from_tailnet="${1:-false}"

    log_info "=== Connectivity Tests ==="

    local extra_vars="test_remote_connectivity=$from_tailnet"

    if [[ "$from_tailnet" == "true" ]]; then
        extra_vars="$extra_vars test_proxmox=true"
    fi

    run_ansible_test "connectivity.yml" "Tailscale Connectivity" "$extra_vars"
}

# Run Proxmox tests
run_proxmox_tests() {
    log_info "=== Proxmox Tests ==="

    run_ansible_test "connectivity.yml" "Proxmox Storage" "test_proxmox=true"
}

# Run quick smoke tests
run_quick_tests() {
    log_info "=== Quick Smoke Tests ==="

    # Check VPS reachability
    if ansible hypervisors -i "$PROJECT_ROOT/ansible/inventory/hosts.yml" -m ping -o 2>/dev/null; then
        log_success "VPS is reachable"
    else
        log_fail "VPS is not reachable"
    fi

    # Check Terraform state
    if [[ -f "$PROJECT_ROOT/terraform/terraform.tfstate" ]]; then
        log_success "Terraform state exists"
    else
        log_skip "Terraform state not found"
    fi

    # Check local Tailscale
    if command -v tailscale &>/dev/null && tailscale status &>/dev/null; then
        log_success "Local Tailscale is connected"
    else
        log_skip "Local Tailscale not available or not connected"
    fi
}

# Print test summary
print_summary() {
    echo ""
    log_info "=== Test Summary ==="
    echo -e "Total Tests:  $TOTAL_TESTS"
    echo -e "${GREEN}Passed:${NC}       $PASSED_TESTS"
    echo -e "${RED}Failed:${NC}       $FAILED_TESTS"
    echo -e "${YELLOW}Skipped:${NC}      $SKIPPED_TESTS"
    echo ""

    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "${RED}Some tests failed. Review output above.${NC}"
        return 1
    else
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    fi
}

main() {
    local test_type="all"
    local from_tailnet="false"
    local quick="false"

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE="true"
                shift
                ;;
            --from-tailnet)
                from_tailnet="true"
                shift
                ;;
            --quick)
                quick="true"
                shift
                ;;
            security|connectivity|proxmox|all)
                test_type="$1"
                shift
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    echo "========================================"
    echo "   CloudEnv Infrastructure Tests"
    echo "   Constitution IV: Test Coverage"
    echo "========================================"
    echo ""

    if [[ "$quick" == "true" ]]; then
        run_quick_tests
    else
        case "$test_type" in
            security)
                run_security_tests
                ;;
            connectivity)
                run_connectivity_tests "$from_tailnet"
                ;;
            proxmox)
                run_proxmox_tests
                ;;
            all)
                run_quick_tests
                run_security_tests || true
                run_connectivity_tests "$from_tailnet" || true
                ;;
        esac
    fi

    print_summary
}

main "$@"
