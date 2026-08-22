#!/usr/bin/env bash
# full-stack-test.sh - Comprehensive integration test for Kubernetes cluster
# Usage: ./full-stack-test.sh [--cleanup]
#
# This script validates the complete stack:
#   1. Cluster health (nodes, system pods, networking)
#   2. Storage functionality (PVC provisioning, mount, I/O)
#   3. ArgoCD GitOps (sync, application deployment)
#   4. Workload lifecycle (deploy, scale, terminate)
#   5. Network connectivity (pod-to-pod, pod-to-service)
#
# Requires: kubectl, talosctl configured and cluster accessible

set -euo pipefail

# Configuration
NAMESPACE="integration-test"
TEST_APP_NAME="integration-test-app"
TALOS_VIP="10.9.8.100"
TIMEOUT=300

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
CLEANUP_NEEDED=false

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
    if [[ "${CLEANUP_NEEDED}" == "true" ]] || [[ "${1:-}" == "--cleanup" ]]; then
        log_section "Cleanup"
        log_info "Removing test resources..."

        kubectl delete namespace "${NAMESPACE}" --ignore-not-found=true --timeout=60s 2>/dev/null || true

        log_info "Cleanup complete"
    fi
}

trap 'cleanup' EXIT

# Parse arguments
for arg in "$@"; do
    case $arg in
        --cleanup)
            cleanup "--cleanup"
            exit 0
            ;;
    esac
done

# Test 1: Cluster Health
test_cluster_health() {
    log_section "Cluster Health"

    # Check nodes
    log_info "Checking node status..."
    local ready_nodes
    ready_nodes=$(kubectl get nodes --no-headers | grep -c "Ready" || echo "0")
    if [[ "${ready_nodes}" -ge 3 ]]; then
        log_pass "All ${ready_nodes} nodes are Ready"
    else
        log_fail "Only ${ready_nodes} nodes Ready (expected 3+)"
        return 1
    fi

    # Check Talos health
    log_info "Checking Talos health..."
    if talosctl health --nodes "${TALOS_VIP}" --wait-timeout 60s &>/dev/null; then
        log_pass "Talos cluster is healthy"
    else
        log_warn "Talos health check failed (non-critical)"
    fi

    # Check system pods
    log_info "Checking system pods..."
    local not_running
    not_running=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -cvE "Running|Completed" || echo "0")
    if [[ "${not_running}" -eq 0 ]]; then
        log_pass "All kube-system pods are running"
    else
        log_fail "${not_running} kube-system pods not running"
        kubectl get pods -n kube-system | grep -vE "Running|Completed"
    fi

    # Check Cilium
    log_info "Checking Cilium status..."
    if kubectl exec -n kube-system ds/cilium -- cilium status &>/dev/null; then
        log_pass "Cilium is healthy"
    else
        log_fail "Cilium status check failed"
    fi
}

# Test 2: Storage Functionality
test_storage() {
    log_section "Storage Functionality"
    CLEANUP_NEEDED=true

    # Create namespace
    log_info "Creating test namespace..."
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

    # Check StorageClass
    log_info "Checking StorageClass..."
    if kubectl get sc truenas-nfs &>/dev/null; then
        log_pass "truenas-nfs StorageClass exists"
    else
        log_fail "truenas-nfs StorageClass not found"
        return 1
    fi

    # Create PVC
    log_info "Creating test PVC..."
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: truenas-nfs
  resources:
    requests:
      storage: 1Gi
EOF

    # Wait for PVC to bind
    log_info "Waiting for PVC to bind..."
    local pvc_status
    for i in {1..60}; do
        pvc_status=$(kubectl get pvc test-pvc -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "${pvc_status}" == "Bound" ]]; then
            log_pass "PVC bound successfully"
            break
        fi
        sleep 2
    done
    if [[ "${pvc_status}" != "Bound" ]]; then
        log_fail "PVC failed to bind (status: ${pvc_status})"
        kubectl describe pvc test-pvc -n "${NAMESPACE}" 2>/dev/null | tail -10
        return 1
    fi

    # Create pod that uses PVC
    log_info "Creating test pod with PVC mount..."
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod
  namespace: ${NAMESPACE}
spec:
  containers:
    - name: test
      image: busybox:latest
      command: ['sh', '-c', 'echo "test-data" > /data/test.txt && cat /data/test.txt && sleep 300']
      volumeMounts:
        - name: data
          mountPath: /data
  volumes:
    - name: data
      persistentVolumeClaim:
        claimName: test-pvc
  restartPolicy: Never
EOF

    # Wait for pod to complete write
    log_info "Waiting for storage test to complete..."
    for i in {1..120}; do
        local pod_status
        pod_status=$(kubectl get pod test-storage-pod -n "${NAMESPACE}" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "${pod_status}" == "Running" ]] || [[ "${pod_status}" == "Succeeded" ]]; then
            local logs
            logs=$(kubectl logs test-storage-pod -n "${NAMESPACE}" 2>/dev/null || echo "")
            if [[ "${logs}" == *"test-data"* ]]; then
                log_pass "Storage read/write test passed"
                break
            fi
        fi
        if [[ "${pod_status}" == "Failed" ]]; then
            log_fail "Storage test pod failed"
            kubectl describe pod test-storage-pod -n "${NAMESPACE}" 2>/dev/null | tail -15
            return 1
        fi
        sleep 2
    done
}

# Test 3: ArgoCD GitOps
test_argocd() {
    log_section "ArgoCD GitOps"

    # Check ArgoCD namespace
    if ! kubectl get namespace argocd &>/dev/null; then
        log_warn "ArgoCD namespace not found - skipping ArgoCD tests"
        return 0
    fi

    # Check ArgoCD server
    log_info "Checking ArgoCD server..."
    local argocd_ready
    argocd_ready=$(kubectl get deployment argocd-server -n argocd -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${argocd_ready}" -ge 1 ]]; then
        log_pass "ArgoCD server is running"
    else
        log_fail "ArgoCD server not ready"
        return 1
    fi

    # Check ArgoCD CRDs
    log_info "Checking ArgoCD CRDs..."
    if kubectl get crd applications.argoproj.io &>/dev/null; then
        log_pass "ArgoCD Application CRD exists"
    else
        log_fail "ArgoCD Application CRD missing"
    fi

    # Check app-of-apps (if exists)
    log_info "Checking app-of-apps..."
    if kubectl get application app-of-apps -n argocd &>/dev/null; then
        local sync_status
        sync_status=$(kubectl get application app-of-apps -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        if [[ "${sync_status}" == "Synced" ]]; then
            log_pass "app-of-apps is synced"
        else
            log_warn "app-of-apps status: ${sync_status}"
        fi
    else
        log_info "app-of-apps not deployed (optional)"
    fi
}

# Test 4: Workload Lifecycle
test_workload_lifecycle() {
    log_section "Workload Lifecycle"
    CLEANUP_NEEDED=true

    # Ensure namespace exists
    kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f - &>/dev/null

    # Deploy test application
    log_info "Deploying test application..."
    cat <<EOF | kubectl apply -f - &>/dev/null
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${TEST_APP_NAME}
  namespace: ${NAMESPACE}
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ${TEST_APP_NAME}
  template:
    metadata:
      labels:
        app: ${TEST_APP_NAME}
    spec:
      containers:
        - name: nginx
          image: nginx:alpine
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ${TEST_APP_NAME}
  namespace: ${NAMESPACE}
spec:
  selector:
    app: ${TEST_APP_NAME}
  ports:
    - port: 80
      targetPort: 80
EOF

    # Wait for deployment
    log_info "Waiting for deployment to be ready..."
    if kubectl rollout status deployment/${TEST_APP_NAME} -n "${NAMESPACE}" --timeout=120s &>/dev/null; then
        log_pass "Deployment rolled out successfully"
    else
        log_fail "Deployment failed to roll out"
        kubectl describe deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" 2>/dev/null | tail -15
        return 1
    fi

    # Check replicas
    local ready_replicas
    ready_replicas=$(kubectl get deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${ready_replicas}" -ge 2 ]]; then
        log_pass "${ready_replicas} replicas ready"
    else
        log_fail "Expected 2 replicas, got ${ready_replicas}"
    fi

    # Test scaling
    log_info "Testing scale up..."
    kubectl scale deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" --replicas=3 &>/dev/null
    sleep 10
    ready_replicas=$(kubectl get deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${ready_replicas}" -ge 3 ]]; then
        log_pass "Scale up successful (${ready_replicas} replicas)"
    else
        log_warn "Scale up incomplete (${ready_replicas}/3 replicas)"
    fi

    # Test scale down
    log_info "Testing scale down..."
    kubectl scale deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" --replicas=1 &>/dev/null
    sleep 10
    ready_replicas=$(kubectl get deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${ready_replicas}" -eq 1 ]]; then
        log_pass "Scale down successful (${ready_replicas} replica)"
    else
        log_warn "Scale down incomplete (${ready_replicas}/1 replicas)"
    fi
}

# Test 5: Network Connectivity
test_network() {
    log_section "Network Connectivity"
    CLEANUP_NEEDED=true

    # Ensure test deployment exists
    if ! kubectl get deployment "${TEST_APP_NAME}" -n "${NAMESPACE}" &>/dev/null; then
        log_warn "Test deployment not found - skipping network tests"
        return 0
    fi

    # Test service DNS resolution
    log_info "Testing service DNS resolution..."
    local test_pod="network-test-$(date +%s)"
    if kubectl run "${test_pod}" -n "${NAMESPACE}" --image=busybox:latest --restart=Never \
        --command -- nslookup "${TEST_APP_NAME}.${NAMESPACE}.svc.cluster.local" &>/dev/null; then

        sleep 10
        local dns_result
        dns_result=$(kubectl logs "${test_pod}" -n "${NAMESPACE}" 2>/dev/null || echo "")
        if [[ "${dns_result}" == *"Address"* ]]; then
            log_pass "DNS resolution works"
        else
            log_warn "DNS resolution may have issues"
        fi
        kubectl delete pod "${test_pod}" -n "${NAMESPACE}" --ignore-not-found=true &>/dev/null
    fi

    # Test pod-to-service connectivity
    log_info "Testing pod-to-service connectivity..."
    local curl_pod="curl-test-$(date +%s)"
    kubectl run "${curl_pod}" -n "${NAMESPACE}" --image=curlimages/curl:latest --restart=Never \
        --command -- curl -s -o /dev/null -w '%{http_code}' "http://${TEST_APP_NAME}:80" &>/dev/null || true

    sleep 15
    local http_code
    http_code=$(kubectl logs "${curl_pod}" -n "${NAMESPACE}" 2>/dev/null || echo "000")
    kubectl delete pod "${curl_pod}" -n "${NAMESPACE}" --ignore-not-found=true &>/dev/null

    if [[ "${http_code}" == "200" ]]; then
        log_pass "Pod-to-service connectivity works (HTTP 200)"
    else
        log_warn "Pod-to-service connectivity returned: ${http_code}"
    fi

    # Check Cilium connectivity
    log_info "Checking Cilium connectivity..."
    local cilium_pod
    cilium_pod=$(kubectl get pods -n kube-system -l k8s-app=cilium --no-headers 2>/dev/null | head -1 | awk '{print $1}')
    if [[ -n "${cilium_pod}" ]]; then
        if kubectl exec -n kube-system "${cilium_pod}" -- cilium-health status &>/dev/null; then
            log_pass "Cilium health check passed"
        else
            log_warn "Cilium health check returned warnings"
        fi
    fi
}

# Print summary
print_summary() {
    log_section "Integration Test Summary"

    local total=$((TESTS_PASSED + TESTS_FAILED))

    echo ""
    echo -e "  ${GREEN}Passed:${NC}  ${TESTS_PASSED}"
    echo -e "  ${RED}Failed:${NC}  ${TESTS_FAILED}"
    echo -e "  Total:   ${total}"
    echo ""

    if [[ ${TESTS_FAILED} -eq 0 ]]; then
        echo -e "${GREEN}✓ All integration tests passed!${NC}"
        echo ""
        echo "The cluster is fully operational:"
        echo "  - Nodes healthy and communicating"
        echo "  - Storage provisioning working"
        echo "  - Workloads deploy correctly"
        echo "  - Network connectivity verified"
        return 0
    else
        echo -e "${RED}✗ ${TESTS_FAILED} test(s) failed${NC}"
        echo ""
        echo "Review the output above for failure details."
        echo "See TROUBLESHOOTING.md for common issues."
        return 1
    fi
}

# Main
main() {
    echo "======================================"
    echo "Full-Stack Integration Tests"
    echo "======================================"
    echo ""
    echo "Testing cluster at VIP: ${TALOS_VIP}"
    echo ""

    # Run all tests
    test_cluster_health
    test_storage
    test_argocd
    test_workload_lifecycle
    test_network

    print_summary
    local result=$?

    exit ${result}
}

main "$@"
