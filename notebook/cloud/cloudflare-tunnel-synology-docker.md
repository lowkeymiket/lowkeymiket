# Publish Self-Hosted Apps from a Synology NAS with Cloudflare Tunnel

## Task
Several small web apps run in Docker on a Synology NAS and had to be reachable from anywhere. The goal: no inbound ports, a sign-in in front of every app, and tunnel software that stays current on its own.

## Solution
`cloudflared` dials out to Cloudflare and requests come back through it, so the router needs no port forward and the NAS no inbound rule. Each stack carries its own sidecar on its own Compose network. A tunnel route alone is public, so every hostname also gets a Cloudflare Access application.

1. Create a remotely managed tunnel in the Cloudflare dashboard (the domain must use Cloudflare DNS) and copy its token.
2. Put `TUNNEL_TOKEN=...` alone in `cloudflared.env`, mode 600, outside git. The token is the tunnel, and `compose config` resolves env files, so keep its output out of logs.
3. Add the sidecar (first block). Point `app.example.com` at `http://app:8080`, the Compose service name, and delete any host port mapping.
4. Create the Access application before the route: one identity provider (Microsoft Entra ID), an Allow policy for one email address, 24-hour sessions. Anything matching no policy is denied. Keep the policy narrow: never "Everyone".
5. Schedule the second block in DSM Task Scheduler as root on Sundays. It finds each running `cloudflared` container by its Compose label, skips stacks that pin a version, then runs `pull` and `up -d --no-deps cloudflared`. If the tunnel does not log "Registered tunnel connection" within two minutes, it exits 1 and DSM sends mail.

## Gotchas
- **Name the sidecar when you deploy.** It depends on the app, not the reverse, so `up -d app` never starts it. Use `up -d app cloudflared`.
- **Do not mark the network `internal: true`.** The sidecar must reach Cloudflare outbound.
- **Warnings are not failures.** The log may complain about the UDP receive buffer and the ICMP proxy. Trust `cloudflared tunnel ready`.
- **Tokens.** Without one the service just restart-loops. A pinned version can read it from a Docker secret with `--token-file`, which needs cloudflared 2025.4.0 or later.

## Result
Three stacks publish through their own tunnels with zero inbound ports on the router or the NAS, and every hostname asks for a sign-in first. The weekly refresh takes under a minute when a release is out and does nothing otherwise. A tunnel that fails to return produces an email.

## Script
If you have a similar task, here is a script you can try. The script is dry-run by default: it lists what it would refresh and changes nothing until `DRY_RUN` is set to `0`.

```yaml
# compose.yaml: an app and its Cloudflare Tunnel sidecar. No ports are published.
services:
  app:
    image: registry.example.com/app:1.0.0
    restart: unless-stopped
    networks: [app-internal]
    # No `ports:`. The sidecar reaches this service as http://app:8080 over the Compose network.
    read_only: true
    tmpfs: [/tmp]
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]

  cloudflared:
    # Default: the newest release. pull_policy always fetches it on every `up`, and the weekly task
    # covers quiet weeks. Pinned variant: image cloudflare/cloudflared:<version>, drop env_file, and use
    # `--token-file /run/secrets/tunnel_token` (a Docker secret; cloudflared 2025.4.0+, readable by uid 65532).
    image: cloudflare/cloudflared:latest
    pull_policy: always
    restart: unless-stopped
    env_file:
      - cloudflared.env # TUNNEL_TOKEN only: mode 600, never in git
    command: ["tunnel", "--no-autoupdate", "--metrics", "127.0.0.1:20241", "run"]
    healthcheck:
      test: ["CMD", "cloudflared", "tunnel", "--metrics", "127.0.0.1:20241", "ready"]
      interval: 60s
      timeout: 5s
      retries: 3
      start_period: 20s
    user: "65532:65532"
    read_only: true
    tmpfs: ["/tmp:size=8m"]
    mem_limit: 128m
    security_opt: ["no-new-privileges:true"]
    cap_drop: [ALL]
    networks: [app-internal]
    depends_on: [app]

networks:
  app-internal:
    driver: bridge
    # Not `internal: true`: the sidecar must reach Cloudflare outbound to build the tunnel.
```

```bash
#!/bin/bash
# cloudflared-weekly.sh: refresh the Cloudflare Tunnel sidecar in every Compose stack on a Synology NAS.
# Usage: DSM Control Panel > Task Scheduler > Create > Scheduled Task > User-defined script,
#        run as root, weekly on Sundays: bash /path/to/cloudflared-weekly.sh
#        A non-zero exit makes DSM send its failure notification.
# Each running `cloudflared` service whose Compose file says image: cloudflare/cloudflared:latest
# is pulled, and Compose recreates it only if a newer image exists. A stack that pins a version is
# left alone. Exits 1 when a Compose step fails or a recreated tunnel does not register in 2 minutes.
# Read-only for publication: DRY_RUN is forced on, so nothing is pulled or recreated. Set 0 to apply.
DRY_RUN=1

set -u
D=/usr/local/bin/docker
LOG="$(cd "$(dirname "$0")" && pwd)/cloudflared-weekly.log"
exec > >(tee -a "$LOG") 2>&1
echo "== $(date -u +%Y-%m-%dT%H:%M:%SZ) weekly tunnel refresh (DRY_RUN=$DRY_RUN)"

if [ "$DRY_RUN" != 1 ]; then   # let an app deploy that starts at the same hour begin, then wait for it (30 min max)
  sleep 90
  for _ in $(seq 60); do ps -eo args= | grep -qE '[a]uto-deploy\.sh' || break; sleep 30; done
fi

rc=0
# Full ids: `compose ps -q` prints them too, and the recreate check below compares the two.
for c in $($D ps -q --no-trunc --filter label=com.docker.compose.service=cloudflared); do
  label() { $D inspect -f "{{index .Config.Labels \"com.docker.compose.$1\"}}" "$c"; }
  p=$(label project)
  args=(-p "$p" --project-directory "$(label project.working_dir)")
  IFS=, read -ra files <<<"$(label project.config_files)"
  for f in "${files[@]}"; do [ -f "$f" ] && args+=(-f "$f"); done
  envf=$(label project.environment_file)
  [ -n "$envf" ] && [ -f "$envf" ] && args+=(--env-file "$envf")
  dc() { $D compose "${args[@]}" "$@"; }

  # `config` resolves env files, so its output only ever goes to grep.
  if ! dc config cloudflared 2>/dev/null | grep -qE '^ +image: cloudflare/cloudflared:latest$'; then
    echo "$p: its compose pins the tunnel version; left alone"; continue
  fi
  if [ "$DRY_RUN" = 1 ]; then
    echo "$p: would pull the newest tunnel and recreate it if it changed"; continue
  fi
  start=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  if ! dc pull -q cloudflared || ! dc up -d --no-deps cloudflared; then
    echo "$p: compose pull/up failed"; rc=1; continue
  fi
  now=$(dc ps -q cloudflared)
  if [ "$now" = "$c" ]; then
    echo "$p: already on the newest tunnel"; continue
  fi
  connected=no
  for _ in $(seq 24); do
    if $D logs --since "$start" "$now" 2>&1 | grep -q 'Registered tunnel connection'; then
      connected=yes; break
    fi
    sleep 5
  done
  version=$($D logs "$now" 2>&1 | grep -oE 'Version [0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ "$connected" = yes ]; then
    echo "$p: tunnel restarted on ${version:-the newest image} and connected"
  else
    echo "$p: the new tunnel (${version:-unknown version}) did not connect within 2 minutes; check: docker logs $now"
    rc=1
  fi
done

# Old cloudflared images left untagged by the pull; in-use and tagged (pinned) images are kept.
if [ "$DRY_RUN" != 1 ] && [ "$rc" = 0 ]; then
  $D image prune -f --filter "label=org.opencontainers.image.source=https://github.com/cloudflare/cloudflared" >/dev/null
fi
echo "== done (exit $rc)"
exit "$rc"
```
