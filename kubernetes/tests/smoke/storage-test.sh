#!/usr/bin/env bash
# storage-test.sh - Validate democratic-csi NFS storage provisioning
# Usage: ./storage-test.sh [--cleanup]
#
# This script validates:
#   1. democratic-csi controller is running
#   2. democratic-csi node agents are running
#   3. StorageClass exists and is default
#   4. PVC can be created and bound
#   5. Pod can mount PVC and write data
#   6. Data persists across pod recreation
#   7. (Optional) Volume snapshot functionality
#
# Creates temporary resources that are cleaned up after testing

set -euo pipefail

# Configuration
TEST_NAMESPACE="storage-test"
STORAGE_CLASS="truenas-nfs"
PVC_NAME="test-pvc"
POD_NAME="test-pod"
TEST_DATA="Hello from Kubernetes storage test - $(date)"
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
    kubectl delete namespace "${TEST_NAMESPACE}" --ignore-not-found=true --wait=false 2>/dev/null || true
}

# Setup test environment
setup() {
    log_section "Setup"

    # Cleanup any existing test resources
    cleanup
    sleep 5  # Wait for namespace cleanup

    log_info "Creating test namespace: ${TEST_NAMESPACE}"
    kubectl create namespace "${TEST_NAMESPACE}"

    log_pass "Test environment ready"
}

# Test democratic-csi components
test_csi_components() {
    log_section "democratic-csi Components"

    # Check namespace exists
    if kubectl get namespace democratic-csi &>/dev/null; then
        log_pass "democratic-csi namespace exists"
    else
        log_fail "democratic-csi namespace not found"
        return 1
    fi

    # Check controller
    local controller_pods
    controller_pods=$(kubectl get pods -n democratic-csi -l app.kubernetes.io/component=controller --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${controller_pods}" -ge 1 ]]; then
        log_pass "democratic-csi controller is running"
    else
        log_fail "democratic-csi controller not running"
    fi

    # Check node agents
    local expected_nodes
    local node_pods
    expected_nodes=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
    node_pods=$(kubectl get pods -n democratic-csi -l app.kubernetes.io/component=node --no-headers 2>/dev/null | grep -c "Running" || echo "0")

    if [[ "${node_pods}" -ge "${expected_nodes}" ]]; then
        log_pass "democratic-csi node agents running on all nodes (${node_pods}/${expected_nodes})"
    else
        log_warn "democratic-csi node agents: ${node_pods}/${expected_nodes} running"
    fi
}

# Test StorageClass
test_storage_class() {
    log_section "StorageClass"

    # Check StorageClass exists
    if kubectl get storageclass "${STORAGE_CLASS}" &>/dev/null; then
        log_pass "StorageClass '${STORAGE_CLASS}' exists"
    else
        log_fail "StorageClass '${STORAGE_CLASS}' not found"
        return 1
    fi

    # Check if it's the default
    local is_default
    is_default=$(kubectl get storageclass "${STORAGE_CLASS}" -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' 2>/dev/null || echo "false")

    if [[ "${is_default}" == "true" ]]; then
        log_pass "StorageClass '${STORAGE_CLASS}' is the default"
    else
        log_warn "StorageClass '${STORAGE_CLASS}' is not marked as default"
    fi

    # Check provisioner
    local provisioner
    provisioner=$(kubectl get storageclass "${STORAGE_CLASS}" -o jsonpath='{.provisioner}')
    log_info "Provisioner: ${provisioner}"
}

# Test PVC creation and binding
test_pvc_binding() {
    log_section "PVC Binding"

    log_info "Creating test PVC..."

    kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ${PVC_NAME}
  namespace: ${TEST_NAMESPACE}
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: ${STORAGE_CLASS}
  resources:
    requests:
      storage: 1Gi
EOF

    # Wait for PVC to bind
    log_info "Waiting for PVC to bind..."
    local retries=$((TIMEOUT / 5))
    while [[ ${retries} -gt 0 ]]; do
        local status
        status=$(kubectl get pvc "${PVC_NAME}" -n "${TEST_NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

        if [[ "${status}" == "Bound" ]]; then
            log_pass "PVC bound successfully"

            # Show PV details
            local pv_name
            pv_name=$(kubectl get pvc "${PVC_NAME}" -n "${TEST_NAMESPACE}" -o jsonpath='{.spec.volumeName}')
            log_info "Bound to PV: ${pv_name}"
            return 0
        fi

        log_info "  PVC status: ${status}, waiting..."
        sleep 5
        ((retries--))
    done

    log_fail "PVC did not bind within ${TIMEOUT}s"
    return 1
}

# Test pod mounting and data persistence
test_pod_mount() {
    log_section "Pod Mount and Data Write"

    log_info "Creating test pod with mounted volume..."

    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${TEST_NAMESPACE}
spec:
  containers:
    - name: test-container
      image: busybox:1.36
      command:
        - sleep
        - "3600"
      volumeMounts:
        - name: test-volume
          mountPath: /data
  volumes:
    - name: test-volume
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
EOF

    # Wait for pod to be ready
    log_info "Waiting for pod to be ready..."
    kubectl wait --for=condition=ready pod/"${POD_NAME}" \
        -n "${TEST_NAMESPACE}" \
        --timeout="${TIMEOUT}s" 2>/dev/null || {
            log_fail "Pod did not become ready"
            return 1
        }

    log_pass "Pod is running with mounted volume"

    # Write test data
    log_info "Writing test data to volume..."
    kubectl exec "${POD_NAME}" -n "${TEST_NAMESPACE}" -- sh -c "echo '${TEST_DATA}' > /data/testfile.txt"
    log_pass "Data written successfully"

    # Read test data back
    log_info "Reading test data from volume..."
    local read_data
    read_data=$(kubectl exec "${POD_NAME}" -n "${TEST_NAMESPACE}" -- cat /data/testfile.txt)

    if [[ "${read_data}" == "${TEST_DATA}" ]]; then
        log_pass "Data read correctly"
    else
        log_fail "Data mismatch: expected '${TEST_DATA}', got '${read_data}'"
    fi
}

# Test data persistence across pod recreation
test_data_persistence() {
    log_section "Data Persistence"

    log_info "Deleting test pod..."
    kubectl delete pod "${POD_NAME}" -n "${TEST_NAMESPACE}" --wait=true

    log_info "Recreating pod..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
  namespace: ${TEST_NAMESPACE}
spec:
  containers:
    - name: test-container
      image: busybox:1.36
      command:
        - sleep
        - "3600"
      volumeMounts:
        - name: test-volume
          mountPath: /data
  volumes:
    - name: test-volume
      persistentVolumeClaim:
        claimName: ${PVC_NAME}
EOF

    # Wait for pod
    kubectl wait --for=condition=ready pod/"${POD_NAME}" \
        -n "${TEST_NAMESPACE}" \
        --timeout="${TIMEOUT}s" 2>/dev/null || {
            log_fail "Pod did not become ready after recreation"
            return 1
        }

    # Verify data persisted
    log_info "Verifying data persistence..."
    local read_data
    read_data=$(kubectl exec "${POD_NAME}" -n "${TEST_NAMESPACE}" -- cat /data/testfile.txt 2>/dev/null || echo "")

    if [[ "${read_data}" == "${TEST_DATA}" ]]; then
        log_pass "Data persisted across pod recreation"
    else
        log_fail "Data did not persist: expected '${TEST_DATA}', got '${read_data}'"
    fi
}

# Test volume expansion (if supported)
test_volume_expansion() {
    log_section "Volume Expansion"

    # Check if expansion is supported
    local allow_expansion
    allow_expansion=$(kubectl get storageclass "${STORAGE_CLASS}" -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null || echo "false")

    if [[ "${allow_expansion}" != "true" ]]; then
        log_warn "Volume expansion not enabled for StorageClass"
        return 0
    fi

    log_info "Expanding PVC from 1Gi to 2Gi..."

    kubectl patch pvc "${PVC_NAME}" -n "${TEST_NAMESPACE}" \
        -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

    # Wait for expansion
    sleep 10

    local new_size
    new_size=$(kubectl get pvc "${PVC_NAME}" -n "${TEST_NAMESPACE}" -o jsonpath='{.status.capacity.storage}')
    log_info "New capacity: ${new_size}"

    if [[ "${new_size}" == "2Gi" ]]; then
        log_pass "Volume expansion successful"
    else
        log_warn "Volume expansion may still be in progress"
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
        echo -e "${GREEN}✓ All storage tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Kubernetes Storage Tests"
    echo "======================================"
    echo ""

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
    test_csi_components
    test_storage_class
    test_pvc_binding
    test_pod_mount
    test_data_persistence
    test_volume_expansion

    # Remove trap before summary
    trap - EXIT

    print_summary
    local result=$?

    # Cleanup
    cleanup

    exit ${result}
}

main "$@"
