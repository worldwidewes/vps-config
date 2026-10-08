# vps-config

Public, secret-free rebuild kit for the `weschance.com` VPS. **Config-only rebuild
model: internal secrets are generated fresh on every new host; only external
credentials are stored (encrypted).**

- **`bootstrap.sh`** — run on a fresh Ubuntu VPS. Installs Docker, lays down the
  Compose projects, generates each `.env` from its `.env.template`, injects
  external keys, creates networks, and starts every stack.
- **`docker/<project>/`** — Compose projects and app source. Secrets are never
  present; they appear as sentinels in `.env.template`.
- **`host/`** — Docker daemon config, boot/tidy systemd unit, prune cron jobs.
- **`scripts/backup.sh`** — nightly restic backup of config + volumes.
- **`scripts/restore-data.sh`** — pull the latest snapshot back into volumes.
- **`scripts/detach-secrets.sh`** — regenerate this split from the live server.
- **`cloud-init/cloud-init.yaml`** — optional unattended provisioning.
- **`inventory/`** — generated projects/volumes/networks/versions.

## How `.env.template` works

Templates carry real **non-secret** config values plus sentinels:

| Sentinel | Replaced at bootstrap with |
|---|---|
| `__GENERATE__` | a fresh random secret (`openssl rand -hex 32`) |
| `__EXTERNAL__` | a value from the encrypted external bundle (blank if absent) |
| `__VPS_IP__` | this host's public IPv4 |

Internal secrets (session keys, DB passwords, app secrets) never leave the server
they were created on. The encrypted bundle holds **only external credentials**
(LLM/API keys, webhooks, tokens).

## Rebuild a wiped VPS

1. Create the VPS; log in as **root**.
2. Run:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/worldwidewes/vps-config/main/bootstrap.sh | bash
   ```
3. If external keys are needed, upload the encrypted bundle to
   `/root/secrets.tar.gz.gpg` first (or set `SECRETS_URL=...`); bootstrap prompts
   for the passphrase.
4. Data (optional): `RESTORE_DATA=1 RESTIC_REPOSITORY=... RESTIC_PASSWORD=... bash bootstrap.sh`
5. Point Cloudflare's wildcard `*` A record at the new IPv4 (DNS only), then verify HTTPS.

## Golden rule

Never commit a live `.env`, key, or token. Before publishing:

```sh
grep -rIlE '(PASSWORD|SECRET|API_KEY|TOKEN)=[^_$]' docker/ | grep -v '\.env\.template'
```

That command must return nothing (templates use sentinels, so they are safe).
