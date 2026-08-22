#!/bin/bash
# Tailscale Routing Fix v2 for Stationary LAN Devices
#
# Problem: When Tailscale accept-routes is enabled, it uses policy routing (table 52)
# which takes precedence over the main routing table. This causes LAN traffic to
# hairpin through Tailscale even when devices are on the same local network.
#
# Solution: Add ip rules with higher priority (lower number) that force local
# subnet traffic to use the main routing table before Tailscale's table 52.
#
# v2 Improvements:
# - Wait for network interface to be ready
# - Proper systemd integration with remote-fs ordering
# - Better error handling and logging

set -euo pipefail

# Configuration - adjust for your network
LOCAL_GATEWAY="10.0.2.1"
LOCAL_INTERFACE="enp2s0f1np1"

# Home LAN subnets that should use local routing (bypass Tailscale)
HOME_SUBNETS=(
    "10.0.2.0/24"       # Local network (workstation's subnet)
    "192.168.0.0/24"
    "192.168.1.0/24"
    "192.168.3.0/24"
    "192.168.8.0/24"
    "192.168.12.0/24"
    "192.168.13.0/24"
    "192.168.16.0/24"
    "192.168.54.0/24"
)

# Priority 5200 is before Tailscale's 5270 (table 52 lookup)
RULE_PRIORITY=5200
ROUTE_METRIC=50
MAX_WAIT_SECONDS=30

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

wait_for_interface() {
    local waited=0
    log "Waiting for interface $LOCAL_INTERFACE to be ready..."

    while [[ $waited -lt $MAX_WAIT_SECONDS ]]; do
        if ip link show "$LOCAL_INTERFACE" 2>/dev/null | grep -q "state UP"; then
            log "Interface $LOCAL_INTERFACE is UP"
            return 0
        fi
        sleep 1
        ((waited++))
    done

    log "ERROR: Interface $LOCAL_INTERFACE not ready after ${MAX_WAIT_SECONDS}s"
    return 1
}

wait_for_gateway() {
    local waited=0
    log "Waiting for gateway $LOCAL_GATEWAY to be reachable..."

    while [[ $waited -lt $MAX_WAIT_SECONDS ]]; do
        if ip route show | grep -q "default via $LOCAL_GATEWAY"; then
            log "Gateway $LOCAL_GATEWAY is reachable"
            return 0
        fi
        sleep 1
        ((waited++))
    done

    log "ERROR: Gateway $LOCAL_GATEWAY not reachable after ${MAX_WAIT_SECONDS}s"
    return 1
}

add_rules() {
    log "Adding ip rules for LAN subnets (priority $RULE_PRIORITY)..."
    local added=0
    for subnet in "${HOME_SUBNETS[@]}"; do
        if ! ip rule show | grep -q "to $subnet lookup main"; then
            ip rule add to "$subnet" lookup main priority "$RULE_PRIORITY"
            log "  Added rule: to $subnet lookup main"
            added=$((added + 1))
        else
            log "  Rule exists: to $subnet lookup main"
        fi
    done
    log "Added $added new rules"
}

add_routes() {
    log "Adding routes for LAN subnets (metric $ROUTE_METRIC)..."
    local added=0
    for subnet in "${HOME_SUBNETS[@]}"; do
        # Skip the local subnet (already has kernel route)
        if ip route show | grep -q "^$subnet dev $LOCAL_INTERFACE proto kernel"; then
            log "  Skipping $subnet (kernel route exists)"
            continue
        fi
        if ! ip route show | grep -q "^$subnet via $LOCAL_GATEWAY.*metric $ROUTE_METRIC"; then
            if ip route add "$subnet" via "$LOCAL_GATEWAY" dev "$LOCAL_INTERFACE" metric "$ROUTE_METRIC" 2>/dev/null; then
                log "  Added route: $subnet via $LOCAL_GATEWAY metric $ROUTE_METRIC"
                added=$((added + 1))
            fi
        else
            log "  Route exists: $subnet via $LOCAL_GATEWAY"
        fi
    done
    log "Added $added new routes"
}

remove_rules() {
    log "Removing ip rules for LAN subnets..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        while ip rule show | grep -q "to $subnet lookup main"; do
            ip rule del to "$subnet" lookup main priority "$RULE_PRIORITY" 2>/dev/null || break
            log "  Removed rule: to $subnet lookup main"
        done
    done
}

remove_routes() {
    log "Removing routes for LAN subnets..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        if ip route show | grep -q "^$subnet via $LOCAL_GATEWAY.*metric $ROUTE_METRIC"; then
            ip route del "$subnet" via "$LOCAL_GATEWAY" dev "$LOCAL_INTERFACE" metric "$ROUTE_METRIC" 2>/dev/null || true
            log "  Removed route: $subnet"
        fi
    done
}

status() {
    echo "=== IP Rules (priority 5200-5280) ==="
    ip rule show | grep -E "520[0-9]|527" || echo "No matching rules"
    echo ""
    echo "=== Tailscale table 52 routes ==="
    ip route show table 52 2>/dev/null | head -10 || echo "Table 52 empty or not exists"
    echo ""
    echo "=== Routes with metric $ROUTE_METRIC ==="
    ip route show | grep "metric $ROUTE_METRIC" || echo "No matching routes"
    echo ""
    echo "=== Tailscale accept-routes status ==="
    if command -v tailscale &>/dev/null; then
        tailscale debug prefs 2>/dev/null | grep -i routeall || echo "Unknown"
    else
        echo "Tailscale not installed"
    fi
    echo ""
    echo "=== Test route lookups ==="
    echo "Local (192.168.3.52):"
    ip route get 192.168.3.52 2>/dev/null || echo "  Cannot lookup"
    echo "CloudEnv (10.0.0.1):"
    ip route get 10.0.0.1 2>/dev/null || echo "  Cannot lookup"
}

case "${1:-}" in
    add|up|start)
        wait_for_interface
        wait_for_gateway
        add_rules
        add_routes
        log "Done. LAN routing fix applied."
        log "You can now enable: tailscale set --accept-routes"
        ;;
    remove|down|stop)
        remove_rules
        remove_routes
        log "Done. LAN routing fix removed."
        log "Consider disabling: tailscale set --accept-routes=false"
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {add|remove|status}"
        echo ""
        echo "Commands:"
        echo "  add     - Add ip rules and routes for LAN priority"
        echo "  remove  - Remove ip rules and routes"
        echo "  status  - Show current routing configuration"
        exit 1
        ;;
esac
