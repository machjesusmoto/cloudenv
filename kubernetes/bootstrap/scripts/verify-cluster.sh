#!/usr/bin/env bash
# verify-cluster.sh - Run all cluster validation tests
# Usage: ./verify-cluster.sh [--quick] [--full]
#
# This script orchestrates all cluster validation:
#   - Quick: Basic health checks only
#   - Full: Complete test suite including network tests

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TESTS_DIR="${PROJECT_ROOT}/tests/smoke"

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

# Run quick health check
run_quick_check() {
    log_info "Running quick health check..."

    if [[ -x "${TESTS_DIR}/cluster-health.sh" ]]; then
        "${TESTS_DIR}/cluster-health.sh"
    else
        log_error "cluster-health.sh not found or not executable"
        return 1
    fi
}

# Run network tests
run_network_tests() {
    log_info "Running network tests..."

    if [[ -x "${TESTS_DIR}/network-test.sh" ]]; then
        "${TESTS_DIR}/network-test.sh"
    else
        log_error "network-test.sh not found or not executable"
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Cluster Verification Suite"
    echo "======================================"
    echo ""

    # Parse arguments
    MODE="quick"
    while [[ $# -gt 0 ]]; do
        case $1 in
            --quick)
                MODE="quick"
                shift
                ;;
            --full)
                MODE="full"
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [--quick] [--full]"
                echo ""
                echo "Options:"
                echo "  --quick      Run basic health checks only (default)"
                echo "  --full       Run complete test suite including network tests"
                echo "  --help, -h   Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # Make test scripts executable
    chmod +x "${TESTS_DIR}"/*.sh 2>/dev/null || true

    local exit_code=0

    # Always run health check
    run_quick_check || exit_code=1

    # Run full tests if requested
    if [[ "${MODE}" == "full" ]]; then
        echo ""
        run_network_tests || exit_code=1
    fi

    echo ""
    echo "======================================"
    if [[ ${exit_code} -eq 0 ]]; then
        log_success "All verification tests passed!"
    else
        log_error "Some verification tests failed"
    fi
    echo "======================================"

    exit ${exit_code}
}

main "$@"
