# Wes — Mission Systems portfolio

A server-rendered Next.js App Router portfolio. The project is intentionally free of analytics, forms, databases, external images, and required secrets. Visual studies are built locally in CSS; the browser-agent screen and architecture are explicitly labeled as concepts.

## Routes

- `/` — cinematic portfolio homepage
- `/projects` — selected projects
- `/projects/local-ai-workstation`
- `/projects/browser-agent`
- `/projects/self-hosted-ai-lab`
- `/projects/trailer-systems-project`
- `/resume` — capabilities and clearly marked résumé draft
- `/lab` — manually maintained work-in-progress notes
- `/robots.txt` and `/sitemap.xml`

## Local development

Requires Node.js 22 or later.

```sh
npm install
npm run dev
```

Checks:

```sh
npm run lint
npm run typecheck
npm run build
npm audit --audit-level=high
```

Set `NEXT_PUBLIC_SITE_URL` to the canonical origin when building. It defaults to `https://dev.weschance.com` in the provided Compose setup. The production site should be rebuilt with `NEXT_PUBLIC_SITE_URL=https://weschance.com` only after the owner approves production routing.

## VPS preview deployment

The Compose service builds a production Next.js standalone image, runs as an unprivileged user, has `restart: unless-stopped`, and exposes no host port. The existing Traefik discovers the Docker labels and serves `https://dev.weschance.com` through the existing HTTPS entrypoint and certificate resolver.

```sh
cd /docker/wes-portfolio-preview
docker compose up -d --build
docker compose ps
curl -fsSI https://dev.weschance.com/
```

Useful operations:

```sh
# Update after editing the source
cd /docker/wes-portfolio-preview
docker image tag wes-portfolio:preview wes-portfolio:known-good
docker compose up -d --build

# Logs and status
docker compose logs --tail=100 -f portfolio
docker compose ps
curl -fsS https://dev.weschance.com/robots.txt
curl -fsS https://dev.weschance.com/sitemap.xml

# Roll back to the previous known-good local image
docker compose stop portfolio
docker image tag wes-portfolio:known-good wes-portfolio:preview
docker compose up -d --no-build
```

This directory is the full deployed build context and should be preserved for a rebuild. Its upstream source is `stacks/wes-portfolio-preview/` in the VPS Trainer repository, but that repository and `bootstrap.sh` were not found under `/root` during the 2026-10-07 server audit. Tag and retain the last known-good image before each rebuild, but the host's daily Docker image-prune job may remove unused rollback images; do not treat a local image tag as an off-server backup. Logs are available with the Compose command above. The app has no separate health endpoint; use an HTTPS request to `/` as the smoke check.

## Content to verify before public launch

- Add Wes’s approved email and GitHub profile/repository links.
- Supply a real résumé file and verified experience, dates, and credentials.
- Verify project contributions, dates, outcomes, screenshots, source links, and live URLs.
- Replace or remove all visible draft and unavailable states.
- Approve production canonical domain and routing before pointing the apex at this service.

No production domain or DNS record is changed by this repository. The Compose router currently matches only `dev.weschance.com`.
