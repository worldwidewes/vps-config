#!/usr/bin/env bash
#
# detach-secrets.sh  (config-only rebuild model)
#
# Runs on the LIVE server. Produces:
#
#   $REPO/docker/<project>/.env.template   public-safe: real non-secret config
#                                          values + sentinels for secrets
#   $REPO/docker/**/<files>                public app source / compose / Dockerfiles
#   $REPO/host/                            public host config
#   $SECRETS/external/<project>.env        ONLY external credentials (LLM keys,
#                                          webhooks) -> encrypt this directory
#   $SECRETS/files/...                     credential files (gh token, opencode)
#
# Sentinels used in .env.template:
#   __GENERATE__   replaced with a fresh random secret at bootstrap time
#   __EXTERNAL__   replaced with a value from the encrypted external bundle
#                  (left blank if not supplied)
#   __VPS_IP__     replaced with the new host's public IPv4 at bootstrap time
#
# Internal secrets (session signing keys, DB passwords, app secrets) are NEVER
# stored. They are regenerated on every build. External keys are the only
# secrets kept in the bundle.
#
set -euo pipefail

REPO_DIR="${REPO_DIR:-/root/vps-iac}"
SECRETS_DIR="${SECRETS_DIR:-/root/vps-secrets}"
SRC_DOCKER="${SRC_DOCKER:-/docker}"
SRC_ROOT="${SRC_ROOT:-/root}"
REPO_OWNER="${REPO_OWNER:-worldwidewes}"
REPO_NAME="${REPO_NAME:-vps-config}"

# Variables supplied by a third party. Kept in the encrypted bundle; everything
# else that looks secret is generated fresh on the new host.
EXTERNAL_RE='^(OPENAI_API_KEY|N8N_INSTANCE_AI_MODEL_API_KEY|BESTBUY_API_KEY|DISCORD_WEBHOOK|NTFY_TOPIC|OPENROUTER_API_KEY|FIREWORKS_API_KEY|GOOGLE_API_KEY|GEMINI_API_KEY|OLLAMA_API_KEY|GLM_API_KEY|KIMI_API_KEY|ARCEEAI_API_KEY|MINIMAX_API_KEY|OPENCODE_ZEN_API_KEY|OPENCODE_GO_API_KEY|HF_TOKEN|DEEPINFRA_API_KEY|XIAOMI_API_KEY|UPSTAGE_API_KEY|RAMP_ROUTER_API_KEY|NEBIUS_API_KEY|TOKENHUB_API_KEY|TOKENPLAN_API_KEY|EXA_API_KEY|PARALLEL_API_KEY|FIRECRAWL_API_KEY|FAL_KEY|HONCHO_API_KEY|BROWSERBASE_API_KEY|GROQ_API_KEY|ELEVENLABS_API_KEY|VOICE_TOOLS_OPENAI_KEY|GITHUB_TOKEN|SLACK_BOT_TOKEN|SLACK_APP_TOKEN|TELEGRAM_BOT_TOKEN)$'
# Looks secret but is minted locally (regenerated at bootstrap).
SENSITIVE_RE='(PASSWORD|SECRET|_KEY|KEY$|TOKEN|WEBHOOK|CREDENTIAL)'

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

render_template() {
  # $1 = source .env, $2 = dest .env.template, $3 = external bundle file
  local src="$1" dst="$2" ext="$3" line key val
  : > "$ext"
  : > "$dst"
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      ''|'#'*) printf '%s\n' "$line" >> "$dst"; continue ;;
    esac
    key="${line%%=*}"; val="${line#*=}"
    printf '%s' "$key" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$' || { printf '%s\n' "$line" >> "$dst"; continue; }

    if [ "$key" = "VPS_IP" ]; then
      printf '%s=__VPS_IP__\n' "$key" >> "$dst"
    elif printf '%s' "$key" | grep -qE "$EXTERNAL_RE"; then
      printf '%s=__EXTERNAL__\n' "$key" >> "$dst"
      if [ -n "$val" ]; then printf '%s=%s\n' "$key" "$val" >> "$ext"; fi
    elif printf '%s' "$key" | grep -qE "$SENSITIVE_RE"; then
      if [ -n "$val" ]; then printf '%s=__GENERATE__\n' "$key" >> "$dst"
      else printf '%s=\n' "$key" >> "$dst"; fi
    else
      printf '%s=%s\n' "$key" "$val" >> "$dst"
    fi
  done < "$src"
}

copy_project_files() {
  local src="$1" dst="$2"
  ( cd "$src" && find . -mindepth 1 \
      -not -path './node_modules/*' -not -path './.next/*' -not -path './out/*' \
      -not -path './.git/*' -not -path './data/*' -not -name 'data' \
      -not -name '.env' -not -name '.env.example' -not -name '.env.template' \
      -not -name '.build.log' -not -name '*.pem' -not -name '*.key' \
      -print0 | tar --null -T - -cf - 2>/dev/null | ( cd "$dst" && tar xf - ) ) || true
}

main() {
  [ "$(id -u)" = "0" ] || { echo "Run as root." >&2; exit 1; }
  log "Repo:    $REPO_DIR (public, no secrets)"
  log "Secrets: $SECRETS_DIR/external + files (encrypt this)"

  rm -rf "$SECRETS_DIR"
  mkdir -p "$REPO_DIR/docker" "$REPO_DIR/host" "$REPO_DIR/inventory" \
           "$SECRETS_DIR/external" "$SECRETS_DIR/files"

  for src in "$SRC_DOCKER"/*/; do
    src="${src%/}"
    [ -f "$src/docker-compose.yml" ] || [ -f "$src/docker-compose.yaml" ] || continue
    name="$(basename "$src")"
    dst="$REPO_DIR/docker/$name"
    mkdir -p "$dst"
    copy_project_files "$src" "$dst"
    if [ -f "$src/.env" ]; then render_template "$src/.env" "$dst/.env.template" "$SECRETS_DIR/external/$name.env"; fi
    log "project $name"
  done

  # Hermes bind-mounted data: only its .env is config; the rest is data.
  local hermes="$SRC_DOCKER/hermes-agent-hyhd"
  if [ -f "$hermes/data/.env" ]; then
    mkdir -p "$REPO_DIR/docker/hermes-agent-hyhd/data"
    render_template "$hermes/data/.env" \
      "$REPO_DIR/docker/hermes-agent-hyhd/data/.env.template" \
      "$SECRETS_DIR/external/hermes-agent-hyhd-data.env"
    log "hermes data/.env"
  fi

  # Credential files (logins) -> secrets bundle.
  if [ -s /root/.ssh/authorized_keys ]; then mkdir -p "$REPO_DIR/host/ssh"; cp -p /root/.ssh/authorized_keys "$REPO_DIR/host/ssh/authorized_keys"; fi
  for f in /root/.config/gh/hosts.yml /root/.config/opencode/cli.json /root/.config/opencode/service.json /root/n8n-opencode-go/set-model.sh; do
    [ -f "$f" ] || continue
    mkdir -p "$SECRETS_DIR/files$(dirname "$f")"
    cp -p "$f" "$SECRETS_DIR/files$f"
  done

  # Host config.
  local H="$REPO_DIR/host"
  if [ -f /etc/docker/daemon.json ]; then cp -p /etc/docker/daemon.json "$H/daemon.json"; fi
  if [ -f /etc/systemd/system/docker-start-no-restart-containers.service ]; then cp -p /etc/systemd/system/docker-start-no-restart-containers.service "$H/systemd/"; fi
  if [ -f /usr/local/sbin/docker-start-no-restart-containers ]; then cp -p /usr/local/sbin/docker-start-no-restart-containers "$H/sbin/"; fi
  for c in /etc/cron.d/docker-builder-prune /etc/cron.d/docker-image-prune; do if [ -f "$c" ]; then cp -p "$c" "$H/cron/"; fi; done

  # Inventory.
  local I="$REPO_DIR/inventory"
  ls -1 "$SRC_DOCKER" | grep -v '^\.' > "$I/projects.txt" 2>/dev/null || true
  docker volume ls -q 2>/dev/null | sort > "$I/volumes.txt"
  docker network ls --format '{{.Name}}' 2>/dev/null | sort > "$I/networks.txt"
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' > "$I/containers.tsv" 2>/dev/null || true
  { echo "docker: $(docker --version 2>/dev/null)"; echo "compose: $(docker compose version 2>/dev/null)"; echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"; } > "$I/versions.txt"
  log "host config + inventory written"

  cat > "$REPO_DIR/.gitignore" <<'EOF'
# Secrets never belong in the public repo.
secrets/
secrets.tar.gz
secrets.tar.gz.gpg
*.env
!*.env.template
*.pem
*.key
id_*
.bootstrap-state
EOF

  echo
  # Keep the bundle minimal: drop external files that carry no values.
  find "$SECRETS_DIR/external" -type f -empty -delete 2>/dev/null || true
  log "External credentials to encrypt (should be small):"
  find "$SECRETS_DIR" -type f | sed 's/^/  /'
  echo
  warn "Encrypt the bundle, keep the passphrase in your password manager:"
  echo "    tar -czf /root/secrets.tar.gz -C $SECRETS_DIR ."
  echo "    gpg --symmetric --cipher-algo AES256 -o /root/secrets.tar.gz.gpg /root/secrets.tar.gz"
  echo "    shred -u /root/secrets.tar.gz && rm -rf $SECRETS_DIR"
  echo
  echo "Repo: $REPO_OWNER/$REPO_NAME"
}

main "$@"
