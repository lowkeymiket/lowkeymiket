# FortiGate Legacy Azure IPsec Tunnel Cleanup

## Problem
A FortiGate still contained monitoring/configuration references to a legacy Azure IPsec tunnel after the associated cloud/on-prem connectivity had been retired. The dashboard exposed the stale VPN object as an invalid interface, creating noise and leaving obsolete configuration in a production firewall.

## Investigation
Firewall monitoring showed the Azure tunnel in the IPsec section with an `Invalid interface` condition while the active Internet architecture had moved to normal WAN/SD-WAN connectivity. Before removing legacy VPN objects, dependencies such as routes and firewall policies had to be considered so cleanup would not break live traffic.

## Fix
The remediation approach was dependency-first: identify the obsolete Phase 1/Phase 2 VPN configuration, inspect any routes or policies referencing the tunnel, remove or update dependent objects, then retire the VPN configuration and validate the firewall dashboard/routing state afterward.

## Result
The stale tunnel and its dependent references were removed so the firewall no longer exposed an invalid legacy path during monitoring or future configuration work.
