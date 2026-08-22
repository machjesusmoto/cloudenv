#!/bin/bash
# Tailscale Routing Fix for Stationary LAN Devices
#
# Problem: When Tailscale accept-routes is enabled, it uses policy routing (table 52)
# which takes precedence over the main routing table. This causes LAN traffic to
# hairpin through Tailscale even when devices are on the same local network.
#
# Solution: Add ip rules with higher priority (lower number) that force local
# subnet traffic to use the main routing table before Tailscale's table 52.
#
# Usage: Run this script before enabling accept-routes, or add to network startup.
#
# For systemd integration, create: /etc/systemd/system/tailscale-lan-routes.service

set -euo pipefail

# Local gateway - adjust for your network
LOCAL_GATEWAY="10.0.2.1"
LOCAL_INTERFACE="enp2s0f1np1"

# Home LAN subnets that should use local routing
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

add_rules() {
    echo "Adding ip rules for LAN subnets (priority $RULE_PRIORITY)..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        if ! ip rule show | grep -q "to $subnet lookup main"; then
            ip rule add to "$subnet" lookup main priority "$RULE_PRIORITY"
            echo "  Added rule: to $subnet lookup main"
        else
            echo "  Rule exists: to $subnet lookup main"
        fi
    done
}

add_routes() {
    echo "Adding routes for LAN subnets (metric $ROUTE_METRIC)..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        # Skip the local subnet (already has kernel route)
        if ip route show | grep -q "^$subnet dev $LOCAL_INTERFACE proto kernel"; then
            echo "  Skipping $subnet (kernel route exists)"
            continue
        fi
        if ! ip route show | grep -q "^$subnet via $LOCAL_GATEWAY.*metric $ROUTE_METRIC"; then
            ip route add "$subnet" via "$LOCAL_GATEWAY" dev "$LOCAL_INTERFACE" metric "$ROUTE_METRIC" 2>/dev/null || true
            echo "  Added route: $subnet via $LOCAL_GATEWAY metric $ROUTE_METRIC"
        else
            echo "  Route exists: $subnet via $LOCAL_GATEWAY"
        fi
    done
}

remove_rules() {
    echo "Removing ip rules for LAN subnets..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        while ip rule show | grep -q "to $subnet lookup main"; do
            ip rule del to "$subnet" lookup main priority "$RULE_PRIORITY" 2>/dev/null || break
            echo "  Removed rule: to $subnet lookup main"
        done
    done
}

remove_routes() {
    echo "Removing routes for LAN subnets..."
    for subnet in "${HOME_SUBNETS[@]}"; do
        if ip route show | grep -q "^$subnet via $LOCAL_GATEWAY.*metric $ROUTE_METRIC"; then
            ip route del "$subnet" via "$LOCAL_GATEWAY" dev "$LOCAL_INTERFACE" metric "$ROUTE_METRIC" 2>/dev/null || true
            echo "  Removed route: $subnet"
        fi
    done
}

status() {
    echo "=== IP Rules (priority 5200-5280) ==="
    ip rule show | grep -E "520[0-9]|527" || echo "No matching rules"
    echo ""
    echo "=== Tailscale table 52 routes ==="
    ip route show table 52 2>/dev/null | head -10 || echo "Table 52 empty"
    echo ""
    echo "=== Routes with metric $ROUTE_METRIC ==="
    ip route show | grep "metric $ROUTE_METRIC" || echo "No matching routes"
    echo ""
    echo "=== Tailscale accept-routes status ==="
    tailscale debug prefs 2>/dev/null | grep -i routeall || echo "Unknown"
}

case "${1:-}" in
    add|up|start)
        add_rules
        add_routes
        echo ""
        echo "Done. You can now enable: tailscale set --accept-routes"
        ;;
    remove|down|stop)
        remove_rules
        remove_routes
        echo ""
        echo "Done. Consider disabling: tailscale set --accept-routes=false"
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
