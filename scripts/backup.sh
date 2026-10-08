#!/usr/bin/env bash
#
# backup.sh - snapshot config + data off-server with restic.
#
# Run on the LIVE server (nightly cron). By default it stops all Compose
# projects for a consistent, point-in-time archive, then restarts them.
#
# Required env (put them in /root/.config/restic/env, chmod 600):
#   RESTIC_REPOSITORY   e.g. s3:https://<accountid>.r2.cloudflarestorage.com/<bucket>
#   RESTIC_PASSWORD     restic repo passphrase
#   AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY   (for R2/S3 backends)
#
# Usage:
#   backup.sh          # cold backup (brief downtime)
#   backup.sh --hot    # no downtime; native DB dumps only for app data
#   backup.sh --init   # initialize the restic repo first
#
set -euo pipefail

STAGE="${STAGE:-/var/lib/vps-backup}"
COMPOSE_GLOBS=("/docker"/*/docker-compose.yml)
HOT=0
INIT=0
for arg in "$@"; do
  case "$arg" in
    --hot) HOT=1 ;;
    --init) INIT=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -f /root/.config/restic/env ] && . /root/.config/restic/env
command -v restic >/dev/null || die "restic not installed."
[ -n "${RESTIC_REPOSITORY:-}" ] || die "RESTIC_REPOSITORY not set."
[ -n "${RESTIC_PASSWORD:-}" ] || die "RESTIC_PASSWORD not set."

[ "$INIT" = "1" ] && { restic snapshots >/dev/null 2>&1 || restic init; }

compose_all() {
  local action="$1"
  for c in "${COMPOSE_GLOBS[@]}"; do
    [ -f "$c" ] || continue
    docker compose -f "$c" "$action" || warn "compose $action failed for $c"
  done
}

mkdir -p "$STAGE/volumes"
rm -f "$STAGE/volumes"/*.tgz

dump_databases() {
  log "Native database dumps"
  # Postgres (MetaMCP, Grafana if present)
  for ps in metamcp-bpeb grafana-zhu6; do
    cid="$(docker ps -q -f "name=${ps}" -f "name=postgres")"
    [ -n "$cid" ] || continue
    docker exec "$cid" sh -c 'pg_dumpall -U "${POSTGRES_USER:-postgres}"' \
      > "$STAGE/${ps}-postgres.sql" 2>/dev/null || warn "pg_dump $ps failed"
  done
  # MySQL (WordPress)
  cid="$(docker ps -q -f "name=wordpress-j2gx" -f "name=db")"
  if [ -n "$cid" ]; then
    docker exec "$cid" sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases' \
      > "$STAGE/wordpress-mysql.sql" 2>/dev/null || warn "mysqldump failed"
  fi
}

export_volumes() {
  log "Exporting named volumes to $STAGE/volumes"
  while IFS= read -r vol; do
    [ -n "$vol" ] || continue
    docker run --rm -v "$vol:/source:ro" -v "$STAGE/volumes:/backup" alpine:3.22 \
      sh -c 'tar czpf "/backup/$1.tgz" -C /source .' sh "$vol" \
      || warn "volume export failed: $vol"
  done < <(docker volume ls -q)
}

[ "$HOT" = "1" ] || { log "Stopping Compose projects (cold backup)"; compose_all stop; }
dump_databases
export_volumes

log "Uploading to restic: $RESTIC_REPOSITORY"
restic backup --tag auto \
  /docker \
  "$STAGE/volumes" \
  "$STAGE"/*.sql \
  /root/grafana-monitoring-example \
  /root/wes-portfolio \
  /root/n8n-opencode-go \
  /root/blender-demo \
  /root/VPS_REBUILD_GUIDE.md 2>/dev/null || true

[ "$HOT" = "1" ] || { log "Restarting Compose projects"; compose_all up -d; }

log "Pruning old snapshots (keep 7 daily, 4 weekly, 6 monthly)"
restic forget --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune

log "Backup complete."
restic snapshots --latest 3
