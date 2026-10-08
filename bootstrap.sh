#!/usr/bin/env bash
#
# bootstrap.sh - rebuild this VPS from the public config repo + external-secrets
# bundle. Internal secrets are generated fresh on this host.
#
# Fresh-server usage (as root):
#
#   curl -fsSL https://raw.githubusercontent.com/worldwidewes/vps-config/main/bootstrap.sh | bash
#
# or upload it plus secrets.tar.gz.gpg and run:  bash /root/bootstrap.sh
#
# Env vars (all optional):
#   REPO_URL, REPO_REF, CONFIG_DIR
#   SECRETS_FILE   default /root/secrets.tar.gz.gpg
#   SECRETS_URL    download the bundle from here first
#   RESTORE_DATA   1 to restore volumes/data from restic (default 0)
#
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/worldwidewes/vps-config.git}"
REPO_REF="${REPO_REF:-main}"
CONFIG_DIR="${CONFIG_DIR:-/opt/vps-config}"
SECRETS_FILE="${SECRETS_FILE:-/root/secrets.tar.gz.gpg}"
SECRETS_URL="${SECRETS_URL:-}"
SECRETS_MNT="${SECRETS_MNT:-/run/vps-secrets}"
RESTORE_DATA="${RESTORE_DATA:-0}"
PUBLIC_IP=""

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[x]\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [ "$(id -u)" = "0" ] || die "Run as root (sudo -i)."
  . /etc/os-release
  case "${ID:-}" in ubuntu|debian) : ;; *) warn "Untested on ${ID:-unknown}; continuing." ;; esac
}

install_prereqs() {
  log "Installing base packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends ca-certificates curl gnupg git openssl jq tar gzip restic
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker present: $(docker --version)"
  else
    log "Installing Docker Engine + Compose plugin"
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh && sh /tmp/get-docker.sh && rm -f /tmp/get-docker.sh
  fi
  systemctl enable --now docker
  docker compose version
}

install_opencode() {
  if command -v opencode >/dev/null 2>&1 || [ -x /root/.opencode/bin/opencode ]; then
    log "OpenCode present: $(/root/.opencode/bin/opencode --version 2>/dev/null)"
  else
    log "Installing OpenCode (V2)"
    curl -fsSL https://opencode.ai/v2/install | bash
  fi
  export PATH="/root/.opencode/bin:$PATH"
  grep -q '/root/.opencode/bin' /root/.bashrc 2>/dev/null \
    || echo 'export PATH=/root/.opencode/bin:$PATH' >> /root/.bashrc
}

detect_ip() {
  PUBLIC_IP="$(curl -fsS --max-time 8 https://api.ipify.org 2>/dev/null || true)"
  [ -n "$PUBLIC_IP" ] || PUBLIC_IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
  log "Public IPv4: ${PUBLIC_IP:-unknown}"
}

clone_repo() {
  if [ -d "$CONFIG_DIR/.git" ]; then
    log "Updating config repo"
    git -C "$CONFIG_DIR" fetch --depth 1 origin "$REPO_REF"
    git -C "$CONFIG_DIR" checkout -f FETCH_HEAD
  else
    log "Cloning config repo"
    rm -rf "$CONFIG_DIR"
    git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$CONFIG_DIR"
  fi
}

host_config() {
  local H="$CONFIG_DIR/host"; [ -d "$H" ] || return 0
  if [ -f "$H/daemon.json" ]; then
    log "Installing /etc/docker/daemon.json"; install -D -m 644 "$H/daemon.json" /etc/docker/daemon.json
    systemctl restart docker; sleep 3
  fi
  [ -f "$H/systemd/docker-start-no-restart-containers.service" ] && install -m 644 "$H/systemd/docker-start-no-restart-containers.service" /etc/systemd/system/
  [ -f "$H/sbin/docker-start-no-restart-containers" ] && install -D -m 755 "$H/sbin/docker-start-no-restart-containers" /usr/local/sbin/
  for c in "$H"/cron/*; do [ -f "$c" ] && install -m 644 "$c" "/etc/cron.d/$(basename "$c")"; done
  [ -f "$H/systemd/docker-start-no-restart-containers.service" ] && { systemctl daemon-reload; systemctl enable docker-start-no-restart-containers.service || true; }
}

deploy_config() {
  [ -d "$CONFIG_DIR/docker" ] || die "Repo has no docker/ directory."
  log "Deploying compose projects to /docker"
  mkdir -p /docker
  ( cd "$CONFIG_DIR" && tar -cf - docker ) | ( cd / && tar -xf - --overwrite )
  if [ -d "$CONFIG_DIR/extras" ]; then
    while IFS= read -r -d '' d; do
      name="$(basename "$d")"; mkdir -p "/root/$name"
      ( cd "$d" && tar -cf - . ) | ( cd "/root/$name" && tar -xf - --overwrite )
    done < <(find "$CONFIG_DIR/extras" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
}

fetch_secrets() {
  if [ -n "$SECRETS_URL" ] && [ ! -f "$SECRETS_FILE" ]; then
    log "Downloading secrets bundle"; curl -fsSL "$SECRETS_URL" -o "$SECRETS_FILE"
  fi
  rm -rf "$SECRETS_MNT"; mkdir -p "$SECRETS_MNT"
  if [ -f "$SECRETS_FILE" ]; then
    log "Decrypting secrets bundle (enter the passphrase)"
    gpg --quiet --batch --yes --decrypt "$SECRETS_FILE" | tar -xzf - -C "$SECRETS_MNT"
  else
    warn "No secrets bundle at $SECRETS_FILE - external keys will be blank."
  fi
}

# Replace key=value in a file safely (value may contain / & = etc).
set_var() {
  local file="$1" key="$2" val="$3" tmp="${1}.tmp.$$"
  awk -v k="$key" -v v="$val" 'index($0, k"=")==1 {print k"="v; next} {print}' "$file" > "$tmp" && mv "$tmp" "$file"
}

# Render a .env.template -> .env, generating internal secrets and overlaying
# external values from the decrypted bundle.
render_file() {
  local tmpl="$1" out="$2" ext="$3" line key
  : > "$out"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      *'=__GENERATE__') key="${line%=__GENERATE__}"; printf '%s=%s\n' "$key" "$(openssl rand -hex 32)" >> "$out" ;;
      *'=__EXTERNAL__') key="${line%=__EXTERNAL__}"; printf '%s=\n' "$key" >> "$out" ;;
      *'=__VPS_IP__')   key="${line%=__VPS_IP__}";   printf '%s=%s\n' "$key" "$PUBLIC_IP" >> "$out" ;;
      *) printf '%s\n' "$line" >> "$out" ;;
    esac
  done < "$tmpl"
  if [ -f "$ext" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      case "$line" in ''|'#'*) continue ;; *=*) set_var "$out" "${line%%=*}" "${line#*=}" ;; esac
    done < "$ext"
  fi
}

render_envs() {
  log "Generating .env files (fresh internal secrets + external keys)"
  local tmpl proj
  for tmpl in /docker/*/.env.template; do
    [ -f "$tmpl" ] || continue
    proj="$(basename "$(dirname "$tmpl")")"
    render_file "$tmpl" "/docker/$proj/.env" "$SECRETS_MNT/external/$proj.env"
  done
  # Hermes bind-mounted data env
  tmpl="/docker/hermes-agent-hyhd/data/.env.template"
  if [ -f "$tmpl" ]; then
    mkdir -p /docker/hermes-agent-hyhd/data
    render_file "$tmpl" "/docker/hermes-agent-hyhd/data/.env" "$SECRETS_MNT/external/hermes-agent-hyhd-data.env"
  fi
}

install_secret_files() {
  [ -d "$SECRETS_MNT/files/root" ] || return 0
  log "Restoring credential files (gh, opencode)"
  cp -a "$SECRETS_MNT/files/root/." /root/
  chmod 600 /root/.config/gh/hosts.yml 2>/dev/null || true
}

create_networks() {
  log "Creating external Docker networks"
  for n in karakeep-ollama metamcp-browser; do
    docker network inspect "$n" >/dev/null 2>&1 || docker network create "$n"
  done
}

restore_data() {
  [ "$RESTORE_DATA" = "1" ] || return 0
  [ -f "$CONFIG_DIR/scripts/restore-data.sh" ] || die "restore-data.sh missing."
  log "Restoring data from restic"
  RESTIC_REPOSITORY="${RESTIC_REPOSITORY:-}" RESTIC_PASSWORD="${RESTIC_PASSWORD:-}" \
    bash "$CONFIG_DIR/scripts/restore-data.sh"
}

start_one() {
  local name="$1" dir="/docker/$1"
  [ -f "$dir/docker-compose.yml" ] || return 1
  log "  up: $name"
  ( cd "$dir" && docker compose up -d --build --remove-orphans ) \
    || { warn "  $name failed (cd $dir && docker compose logs)"; return 1; }
}

start_stacks() {
  log "Starting stacks in dependency order"
  local order=(traefik-f7zu wordpress-j2gx searxng-nfja open-webui-4fhy metamcp-bpeb browser-use-mcp
               karakeep-d8om n8n-with-ai-assistant-v7zl hermes-agent-hyhd apps-portal-vq3c
               ps5stock-5c2b wes-portfolio-preview)
  local started=" " name
  for name in "${order[@]}"; do start_one "$name" && started="$started$name "; done
  for dir in /docker/*/; do
    name="$(basename "${dir%/}")"
    case "$started" in *" $name "*) continue ;; esac
    start_one "$name" || true
  done
}

verify() {
  echo
  log "Container status:"
  docker ps --format 'table {{.Names}}\t{{.Status}}' | sed 's/^/  /'
  echo
  cat <<'EOF'
Next steps:
  1. Point Cloudflare's wildcard (*) A record at this server's public IPv4 (DNS only).
  2. Verify Traefik certs:  docker logs --tail 50 traefik-f7zu-traefik-1
  3. Check a site:          curl -I https://chat.weschance.com/
EOF
}

main() {
  require_root; install_prereqs; install_docker; install_opencode; detect_ip; clone_repo
  host_config; deploy_config; fetch_secrets; restore_data; render_envs
  install_secret_files; create_networks; start_stacks; verify
}

main "$@"
