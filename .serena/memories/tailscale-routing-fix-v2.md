# Tailscale Routing Fix v2 - Session 2026-01-09

## Summary
Reinstalled and improved Tailscale routing fix on fresh CachyOS installation.

## Key Improvements
1. Fixed bash arithmetic bug (added++ vs added=$((added+1)))
2. Added wait_for_interface() and wait_for_gateway() functions
3. Proper systemd ordering with Before=remote-fs-pre.target
4. Updated fstab with _netdev and x-systemd dependencies

## Deployed Files
- /usr/local/bin/tailscale-routing-fix.sh (v2)
- /etc/systemd/system/tailscale-lan-routes.service
- /etc/fstab updated with proper NFS mount options

## Tailscale Status
- Node: cachy-moto (100.97.16.60)
- accept-routes: enabled
- Routing fix: active

## Verified Working
- NFS mount to 192.168.3.52 (TrueNAS)
- IP rules at priority 5200
- Routes with metric 50

## Pending
- Reboot test to verify boot ordering
- pve-vps connectivity (may be offline)