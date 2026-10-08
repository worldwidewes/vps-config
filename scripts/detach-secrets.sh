#!/usr/bin/env bash
#
# detach-secrets.sh
#
# Runs on the LIVE server. Splits the running Docker setup into:
#
#   $REPO/docker/<project>/   public-safe config (compose files, app source,
#                             Dockerfiles, and .env.example placeholders)
#   $REPO/host/               public-safe host config (docker daemon, systemd,
#                             cron)
#   $REPO/inventory/          generated lists (projects, volumes, images)
#   $SECRETS_DIR/             REAL secret values (.env files, bind-mounted .env,
#                             gh tokens). Never commit this directory.
#
# Nothing under $REPO/docker or $REPO/host should ever contain a live secret.
# Review the diff before publishing. Then encrypt the secrets directory:
#
#   tar -czf secrets.tar.gz -C "$SECRETS_DIR" .
#   gpg --symmetric --cipher-algo AES256 -o secrets.tar.gz.gpg secrets.tar.gz
#   shred -u secrets.tar.gz
#
# and store secrets.tar.gz.gpg OFF-SERVER (private object storage / gist /
# password manager). The passphrase is typed at bootstrap time and is never
# stored anywhere.
#
set -euo pipefail

REPO_DIR="${REPO_DIR:-/root/vps-iac}"
SECRETS_DIR="${SECRETS_DIR:-/root/vps-secrets}"
SRC_DOCKER="${SRC_DOCKER:-/docker}"
SRC_ROOT="${SRC_ROOT:-/root}"
REPO_OWNER="${REPO_OWNER:-worldwidewes}"
REPO_NAME="${REPO_NAME:-vps-config}"

# Directories/files that must never land in the public repo.
SKIP_NAMES_RE='(^|/)(node_modules|\.next|out|\.git|\.env|\.build\.log|data)(/|$)'
# Secret-looking files that must always be pulled out into the secrets bundle
# even if they live in an otherwise-public directory.
SECRET_FILE_RE='(\.env$|gh-env\.sh$|set-model\.sh$|\.pem$|\.key$|id_(rsa|ed25519|ecdsa))'

log() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

require_root() {
  [ "$(id -u)" = "0" ] || { echo "Run as root." >&2; exit 1; }
}

# Turn a real .env into a placeholder .env.example (names kept, values blank).
make_example() {
  local src="$1" dst="$2"
  sed -E 's/^([A-Za-z_][A-Za-z0-9_]*)=.*/\1=/' "$src" > "$dst"
}

# Copy everything public-safe from a project directory.
copy_project() {
  local src="$1" name dst
  name="$(basename "$src")"
  dst="$REPO_DIR/docker/$name"
  mkdir -p "$dst"

  # Copy with a hard exclude list; rsync is not assumed to exist.
  ( cd "$src" && find . -mindepth 1 \
      -not -path './node_modules/*' -not -path './.next/*' -not -path './out/*' \
      -not -path './.git/*' -not -path './data/*' -not -name 'data' \
      -not -name '.env' -not -name '.build.log' \
      -not -name '*.pem' -not -name '*.key' \
      -print0 | tar --null -T - -cf - 2>/dev/null | ( cd "$dst" && tar xf - ) ) || true

  # Public placeholder for the project's .env
  if [ -f "$src/.env" ]; then
    make_example "$src/.env" "$dst/.env.example"
  fi

  # Real .env into the secrets bundle
  if [ -f "$src/.env" ]; then
    mkdir -p "$SECRETS_DIR/docker/$name"
    cp -p "$src/.env" "$SECRETS_DIR/docker/$name/.env"
  fi
  log "project $name -> repo + secrets"
}

main() {
  require_root
  log "Repo dir:    $REPO_DIR"
  log "Secrets dir: $SECRETS_DIR (never commit)"

  mkdir -p "$REPO_DIR/docker" "$REPO_DIR/host" "$REPO_DIR/inventory" "$SECRETS_DIR/docker"

  # ---- Project configs ----
  for src in "$SRC_DOCKER"/*/; do
    [ -f "$src/docker-compose.yml" ] || [ -f "$src/docker-compose.yaml" ] || continue
    copy_project "${src%/}"
  done

  # ---- Hermes bind-mounted secrets + scripts (data/ is 500M, config only) ----
  local hermes="$SRC_DOCKER/hermes-agent-hyhd"
  if [ -d "$hermes/data" ]; then
    mkdir -p "$SECRETS_DIR/docker/hermes-agent-hyhd/data/skills/software-development/github/scripts"
    [ -f "$hermes/data/.env" ] && cp -p "$hermes/data/.env" "$SECRETS_DIR/docker/hermes-agent-hyhd/data/.env"
    local ghenv="$hermes/data/skills/software-development/github/scripts/gh-env.sh"
    [ -f "$ghenv" ] && cp -p "$ghenv" "$SECRETS_DIR/docker/hermes-agent-hyhd/data/skills/software-development/github/scripts/gh-env.sh"
    # Placeholder into the repo so the layout is visible
    mkdir -p "$REPO_DIR/docker/hermes-agent-hyhd/data/skills/software-development/github/scripts"
    [ -f "$hermes/data/.env" ] && make_example "$hermes/data/.env" "$REPO_DIR/docker/hermes-agent-hyhd/data/.env.example"
    log "hermes bind data secret extracted"
  fi

  # ---- Extra /root scripts that reference secrets ----
  if [ -d "$SRC_ROOT/n8n-opencode-go" ]; then
    mkdir -p "$REPO_DIR/extras/n8n-opencode-go" "$SECRETS_DIR/root/n8n-opencode-go"
    ( cd "$SRC_ROOT/n8n-opencode-go" && find . -maxdepth 1 -type f \
        -not -name '*.key' -print0 | tar --null -T - -cf - | ( cd "$REPO_DIR/extras/n8n-opencode-go" && tar xf - ) ) || true
    [ -f "$SRC_ROOT/n8n-opencode-go/set-model.sh" ] && cp -p "$SRC_ROOT/n8n-opencode-go/set-model.sh" "$SECRETS_DIR/root/n8n-opencode-go/set-model.sh"
  fi

  # ---- Host config ----
  local H="$REPO_DIR/host"
  [ -f /etc/docker/daemon.json ] && cp -p /etc/docker/daemon.json "$H/daemon.json"
  [ -f /etc/systemd/system/docker-start-no-restart-containers.service ] && \
    cp -p /etc/systemd/system/docker-start-no-restart-containers.service "$H/systemd/"
  [ -f /usr/local/sbin/docker-start-no-restart-containers ] && \
    cp -p /usr/local/sbin/docker-start-no-restart-containers "$H/sbin/"
  for c in /etc/cron.d/docker-builder-prune /etc/cron.d/docker-image-prune; do
    [ -f "$c" ] && cp -p "$c" "$H/cron/"
  done
  log "host config captured"

  # ---- User logins / credentials (never public) ----
  # SSH authorized_keys is a PUBLIC key; safe to keep in the repo.
  if [ -s /root/.ssh/authorized_keys ]; then
    mkdir -p "$REPO_DIR/host/ssh"
    cp -p /root/.ssh/authorized_keys "$REPO_DIR/host/ssh/authorized_keys"
  fi
  # These carry live credentials (GitHub token, OpenCode session) -> secrets.
  mkdir -p "$SECRETS_DIR/root/.config/gh" "$SECRETS_DIR/root/.config/opencode"
  [ -f /root/.config/gh/hosts.yml ] && cp -p /root/.config/gh/hosts.yml "$SECRETS_DIR/root/.config/gh/hosts.yml"
  for f in cli.json service.json; do
    [ -f "/root/.config/opencode/$f" ] && cp -p "/root/.config/opencode/$f" "$SECRETS_DIR/root/.config/opencode/$f"
  done
  log "user credentials captured into secrets bundle"

  # ---- Inventory ----
  local I="$REPO_DIR/inventory"
  ls -1 "$SRC_DOCKER" | grep -v '^\.' > "$I/projects.txt" 2>/dev/null || true
  docker volume ls -q 2>/dev/null | sort > "$I/volumes.txt"
  docker volume ls --format '{{.Name}}' 2>/dev/null | sort > "$I/volumes.txt"
  docker network ls --format '{{.Name}}' 2>/dev/null | sort > "$I/networks.txt"
  docker ps -a --format '{{.Names}}\t{{.Image}}\t{{.Status}}' > "$I/containers.tsv" 2>/dev/null || true
  docker compose version > "$I/versions.txt" 2>/dev/null || true
  { echo "docker: $(docker --version 2>/dev/null)"; echo "compose: $(docker compose version 2>/dev/null)"; echo "os: $(. /etc/os-release; echo "$PRETTY_NAME")"; } >> "$I/versions.txt"
  log "inventory written"

  # ---- Static bootstrap helpers ----
  cat > "$REPO_DIR/.gitignore" <<'EOF'
# Secrets never belong in the public repo.
secrets/
secrets.tar.gz
secrets.tar.gz.gpg
*.env
!*.env.example
*.pem
*.key
id_*
.bootstrap-state
EOF

  log "done."
  echo
  warn "Now encrypt and REMOVE the plaintext secrets:"
  echo "    tar -czf $SECRETS_DIR/../secrets.tar.gz -C $SECRETS_DIR ."
  echo "    gpg --symmetric --cipher-algo AES256 -o $SECRETS_DIR/../secrets.tar.gz.gpg $SECRETS_DIR/../secrets.tar.gz"
  echo "    shred -u $SECRETS_DIR/../secrets.tar.gz"
  echo
  warn "Then review. This value-level scan must print nothing:"
  cat <<EOF
    while IFS= read -r f; do
      while IFS= read -r line; do
        case "\$line" in \\#*|'') continue;; esac
        key=\${line%%=*}; val=\${line#*=}
        echo "\$key" | grep -qE '(PASSWORD|SECRET|API_KEY|_KEY|TOKEN|WEBHOOK|PRIVATE)' || continue
        val=\${val%\\"}; val=\${val#\\"}
        [ \${#val} -lt 6 ] && continue
        case "\$val" in '\\\${'*|*your_*|*xxx*|*CHANGE*) continue;; esac
        grep -rIFq -- "\$val" "$REPO_DIR" && echo "LEAK: \$key"
      done < "\$f"
    done < <(find "$SECRETS_DIR" -type f)
EOF
  echo
  echo "Repo owner/name used by bootstrap: $REPO_OWNER/$REPO_NAME"
}

main "$@"
