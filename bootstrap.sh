#!/usr/bin/env bash
#
# bootstrap.sh - rebuild this VPS from the public config repo + secrets bundle.
#
# Fresh-server usage (as root):
#
#   # Option A: upload this script
#   scp bootstrap.sh root@NEW_IP:/root/ && ssh root@NEW_IP 'bash /root/bootstrap.sh'
#
#   # Option B: public URL
#   curl -fsSL https://raw.githubusercontent.com/worldwidewes/vps-config/main/bootstrap.sh | bash
#
# Configuration (env vars, all optional):
#   REPO_URL        git URL of the PUBLIC config repo
#   REPO_REF        branch/tag to deploy (default: main)
#   CONFIG_DIR      working checkout (default: /opt/vps-config)
#   SECRETS_FILE    path to secrets.tar.gz.gpg (default: /root/secrets.tar.gz.gpg)
#   SECRETS_URL     if set, download the secrets bundle from here first
#   RESTORE_DATA    1 to restore volumes/data from restic (default: 0)
#   RESTIC_REPOSITORY / RESTIC_PASSWORD  required if RESTORE_DATA=1
#
# The secrets bundle passphrase is prompted for interactively and is never
# written to disk or logs.
#
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/worldwidewes/vps-config.git}"
REPO_REF="${REPO_REF:-main}"
CONFIG_DIR="${CONFIG_DIR:-/opt/vps-config}"
SECRETS_FILE="${SECRETS_FILE:-/root/secrets.tar.gz.gpg}"
SECRETS_URL="${SECRETS_URL:-}"
RESTORE_DATA="${RESTORE_DATA:-0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [ "$(id -u)" = "0" ] || die "Run as root (sudo -i)."
  [ -r /etc/os-release ] || die "Unknown OS."
  . /etc/os-release
  case "${ID:-}" in
    ubuntu|debian) : ;;
    *) warn "Tested on Ubuntu/Debian; continuing on ${ID:-unknown}." ;;
  esac
}

install_prereqs() {
  log "Installing base packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl gnupg git jq tar gzip restic
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
  else
    log "Installing Docker Engine + Compose plugin (official convenience script)"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
  fi
  systemctl enable --now docker
  docker compose version
}

host_config() {
  local H="$CONFIG_DIR/host"
  [ -d "$H" ] || { warn "No host/ config in repo; skipping."; return; }

  if [ -f "$H/daemon.json" ]; then
    log "Installing /etc/docker/daemon.json"
    install -D -m 644 "$H/daemon.json" /etc/docker/daemon.json
    systemctl restart docker
    sleep 3
  fi
  [ -f "$H/systemd/docker-start-no-restart-containers.service" ] && \
    install -m 644 "$H/systemd/docker-start-no-restart-containers.service" \
      /etc/systemd/system/docker-start-no-restart-containers.service
  [ -f "$H/sbin/docker-start-no-restart-containers" ] && \
    install -D -m 755 "$H/sbin/docker-start-no-restart-containers" \
      /usr/local/sbin/docker-start-no-restart-containers
  for c in "$H"/cron/*; do
    [ -f "$c" ] && install -m 644 "$c" "/etc/cron.d/$(basename "$c")"
  done
  if [ -f "$H/systemd/docker-start-no-restart-containers.service" ]; then
    systemctl daemon-reload
    systemctl enable docker-start-no-restart-containers.service || true
  fi
}

clone_repo() {
  if [ -d "$CONFIG_DIR/.git" ]; then
    log "Updating config repo in $CONFIG_DIR"
    git -C "$CONFIG_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$CONFIG_DIR" checkout -f FETCH_HEAD
  else
    log "Cloning config repo into $CONFIG_DIR"
    rm -rf "$CONFIG_DIR"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$CONFIG_DIR"
  fi
}

deploy_config() {
  [ -d "$CONFIG_DIR/docker" ] || die "Repo has no docker/ directory."
  log "Deploying compose projects to /docker"
  mkdir -p /docker
  ( cd "$CONFIG_DIR" && tar -cf - docker ) | ( cd / && tar -xf - --overwrite )
  # Copy any /root extras that are public-safe
  if [ -d "$CONFIG_DIR/extras" ]; then
    while IFS= read -r -d '' d; do
      name="$(basename "$d")"
      mkdir -p "/root/$name"
      ( cd "$d" && tar -cf - . ) | ( cd "/root/$name" && tar -xf - --overwrite )
    done < <(find "$CONFIG_DIR/extras" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
}

fetch_secrets() {
  if [ -n "$SECRETS_URL" ] && [ ! -f "$SECRETS_FILE" ]; then
    log "Downloading secrets bundle from $SECRETS_URL"
    curl -fsSL "$SECRETS_URL" -o "$SECRETS_FILE"
  fi
  [ -f "$SECRETS_FILE" ] || die "Secrets bundle not found at $SECRETS_FILE. Upload it or set SECRETS_URL."
  log "Decrypting secrets bundle (you will be prompted for the passphrase)"
  gpg --quiet --batch --yes --decrypt "$SECRETS_FILE" \
    | tar -xzf - -C /
  log "Secrets restored into /docker/**/.env and /root"
}

create_networks() {
  log "Creating external Docker networks"
  for n in karakeep-ollama metamcp-browser; do
    docker network inspect "$n" >/dev/null 2>&1 || docker network create "$n"
  done
}

restore_data() {
  [ "$RESTORE_DATA" = "1" ] || return 0
  [ -f "$CONFIG_DIR/scripts/restore-data.sh" ] || die "restore-data.sh missing from repo."
  log "Restoring data from restic"
  RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}" RESTIC_PASSWORD="${RESTIC_PASSWORD:-}" \
    bash "$CONFIG_DIR/scripts/restore-data.sh"
}

start_stacks() {
  log "Starting stacks in dependency order"
  local order=(
    traefik-f7zu
    wordpress-j2gx
    searxng-nfja
    open-webui-4fhy
    metamcp-bpeb
    browser-use-mcp
    karakeep-d8om
    n8n-with-ai-assistant-v7zl
    hermes-agent-hyhd
    apps-portal-vq3c
    ps5stock-5c2b
    wes-portfolio-preview
  )
  local started=" "
  for name in "${order[@]}"; do
    start_one "$name" && started="$started$name "
  done
  for dir in /docker/*/; do
    name="$(basename "${dir%/}")"
    case "$started" in *" $name "*) continue ;; esac
    start_one "$name" || true
  done
}

start_one() {
  local name="$1" dir="/docker/$1"
  [ -f "$dir/docker-compose.yml" ] || return 1
  log "  up: $name"
  ( cd "$dir" && docker compose up -d --build --remove-orphans ) \
    || { warn "  $name failed to start (check: cd $dir && docker compose logs)"; return 1; }
}

verify() {
  echo
  log "Container status:"
  docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | sed 's/^/  /'
  echo
  log "Next steps:"
  cat <<'EOF'
  1. Point the Cloudflare wildcard A record (*) at this server's public IPv4
     (start with DNS only / grey cloud).
  2. Wait for Traefik to obtain Let's Encrypt certs, then verify:
       docker logs --tail 50 traefik-f7zu-traefik-1
       curl -I https://chat.weschance.com/
  3. Review any stack that failed above.
EOF
}

main() {
  require_root
  install_prereqs
  install_docker
  clone_repo
  host_config
  deploy_config
  fetch_secrets
  create_networks
  restore_data
  start_stacks
  verify
}

main "$@"
