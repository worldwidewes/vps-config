# vps-config

Public, secret-free rebuild kit for the `weschance.com` VPS.

- **`bootstrap.sh`** — run on a fresh Ubuntu VPS to install Docker, lay down the
  Compose projects, decrypt your secrets bundle, and start every stack.
- **`docker/`** — all Compose projects and app source. Contains `.env.example`
  placeholders only; **never** real values.
- **`host/`** — Docker daemon config, boot/tidy systemd unit, prune cron jobs.
- **`scripts/backup.sh`** — nightly restic backup of config + volumes to
  object storage.
- **`scripts/restore-data.sh`** — pull the latest snapshot back into volumes.
- **`cloud-init/cloud-init.yaml`** — optional unattended provisioning.
- **`inventory/`** — generated lists of projects, volumes, networks, versions.

## How secrets are kept out of this repo

| Layer | Location | Secret? |
|---|---|---|
| Compose + config | this repo | no |
| `.env` values | `secrets.tar.gz.gpg` (GPG AES-256) | yes, encrypted |
| Volumes / DBs | restic repo on Cloudflare R2 | yes, encrypted |

The GPG passphrase lives only in your password manager. Store the generated
`secrets.tar.gz.gpg` somewhere private (private object storage, private gist, or
your password manager) — **not** in this repository.

## Rebuild a wiped VPS

1. Create the VPS, log in as **root**.
2. Trigger the build — either:
   - upload: `scp bootstrap.sh root@NEW_IP:/root/ && ssh root@NEW_IP 'bash /root/bootstrap.sh'`, or
   - public URL: `curl -fsSL https://raw.githubusercontent.com/worldwidewes/vps-config/main/bootstrap.sh | bash`
3. When prompted, enter the GPG passphrase for your secrets bundle. If the
   bundle isn't at `/root/secrets.tar.gz.gpg`, upload it first or set
   `SECRETS_URL=<url>`.
4. To also restore data: `RESTORE_DATA=1 RESTIC_REPOSITORY=... RESTIC_PASSWORD=... bash bootstrap.sh`
5. Point the Cloudflare wildcard `*` A record at the new IPv4 (DNS only), then
   verify HTTPS through Traefik.

## Golden rule

Never commit a live `.env`, key, or token. Before publishing:

```sh
grep -rIlE '(PASSWORD|SECRET|API_KEY|TOKEN)=[^ ]' . | grep -v '.env.example'
```

That command must return nothing.
