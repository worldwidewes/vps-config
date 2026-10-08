#!/usr/bin/env bash
#
# restore-data.sh - restore volumes + bind data from a restic snapshot.
#
# Called automatically by bootstrap.sh when RESTORE_DATA=1, or run manually.
#
# Required env (same file as backup.sh):
#   RESTIC_REPOSITORY, RESTIC_PASSWORD (+ cloud creds)
#
# Design notes:
#   - Compose files / app source are NOT restored from the backup. The public
#     config repo is the source of truth for configuration.
#   - Only data is restored: named Docker volumes, the Hermes bind-mounted
#     data directory, and select /root project directories.
#
set -euo pipefail

RESTORE_ROOT="${RESTORE_ROOT:-/var/lib/vps-restore}"
FORCE="${FORCE:-0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

[ -f /root/.config/restic/env ] && . /root/.config/restic/env
command -v restic >/dev/null || die "restic not installed."
[ -n "${RESTIC_REPOSITORY:-}" ] || die "RESTIC_REPOSITORY not set."
[ -n "${RESTIC_PASSWORD:-}" ] || die "RESTIC_PASSWORD not set."

log "Restoring latest snapshot into $RESTORE_ROOT"
rm -rf "$RESTORE_ROOT"
mkdir -p "$RESTORE_ROOT"
restic restore latest --target "$RESTORE_ROOT"

# ---- Named volumes ----
VOL_DIR="$RESTORE_ROOT/var/lib/vps-backup/volumes"
if [ -d "$VOL_DIR" ]; then
  log "Importing named volumes"
  while IFS= read -r tgz; do
    [ -n "$tgz" ] || continue
    vol="$(basename "$tgz" .tgz)"
    if docker volume inspect "$vol" >/dev/null 2>&1 && [ "$FORCE" != "1" ]; then
      warn "volume $vol already exists; skipping (set FORCE=1 to overwrite)"
      continue
    fi
    docker volume create "$vol" >/dev/null
    docker run --rm -v "$vol:/target" -v "$VOL_DIR:/backup:ro" alpine:3.22 \
      sh -c 'tar xzpf "/backup/$1.tgz" -C /target' sh "$vol" \
      && log "  restored volume: $vol" || warn "  failed: $vol"
  done < <(find "$VOL_DIR" -name '*.tgz')
else
  warn "No volume archives found in snapshot ($VOL_DIR)."
fi

# ---- Hermes bind-mounted data ----
HERMES_SRC="$RESTORE_ROOT/docker/hermes-agent-hyhd/data"
if [ -d "$HERMES_SRC" ]; then
  log "Restoring Hermes bind data"
  mkdir -p /docker/hermes-agent-hyhd/data
  cp -a "$HERMES_SRC/." /docker/hermes-agent-hyhd/data/
fi

# ---- /root project directories ----
for name in grafana-monitoring-example wes-portfolio n8n-opencode-go blender-demo; do
  src="$RESTORE_ROOT/root/$name"
  [ -d "$src" ] || continue
  log "Restoring /root/$name"
  mkdir -p "/root/$name"
  cp -a "$src/." "/root/$name/"
done

log "Data restore complete. Start stacks with bootstrap.sh start, or:"
echo "    cd /docker/<project> && docker compose up -d"
