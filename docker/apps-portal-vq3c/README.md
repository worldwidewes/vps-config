# Apps Portal

The static launch page at <https://apps.weschance.com> links to the public tools hosted on this VPS. It is served by the `nginx:alpine` container and routed by Traefik.

## Listed services

| App | URL | Purpose |
|---|---|---|
| Open WebUI | <https://chat.weschance.com> | Chat with hosted AI models |
| AnythingLLM | <https://anythingllm.weschance.com> | Document and AI workspaces |
| Hermes Agent | <https://hermes-agent.weschance.com> | Personal AI agent dashboard |
| Karakeep | <https://karakeep.weschance.com> | Save and organize links and notes |
| n8n | <https://n8n.weschance.com> | Workflow automation |
| SearXNG | <https://searxng.weschance.com> | Metasearch |
| Grafana | <https://grafana.weschance.com> | Server and container monitoring |
| OpenSpeedTest | <https://speedtest.weschance.com> | Test the client-to-VPS network path |
| Blender | <https://blender.weschance.com> | Legacy portal link; its Docker stack was not found in the 2026-10-07 server audit, so availability is unverified |

Ollama is internal-only and is intentionally not linked. Some public apps require sign-in.

## Update and deploy

Edit `index.html` to change the cards, then run:

```sh
cd /docker/apps-portal-vq3c
docker compose up -d
curl -fsSI https://apps.weschance.com/
```

The app list is static; adding or removing a container does not update the page automatically. The domain resolves through the existing wildcard DNS record, and Traefik manages HTTPS with its Let's Encrypt resolver.

The portal's Blender card remains a static link, but no matching `/docker/blender-ad7a` project, container, or volume was present in the latest audit. Remove the card or restore/recreate the Blender stack if it should be a live service.
