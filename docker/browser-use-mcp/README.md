# Browser Use MCP

This stack runs the official Browser Use open-source MCP server in a dedicated,
headless container. `mcp-proxy` bridges its stdio transport to Streamable HTTP
for MetaMCP.

## MetaMCP connection

Add a server in MetaMCP with:

- **Type:** Streamable HTTP
- **URL:** `http://browser-use:8080/mcp`
- **Authentication:** None (reachable only on the private `metamcp-browser` Docker network)

The Browser Use container has no published host ports and is not exposed through
Traefik. The shared network connects it only to MetaMCP's app container, not its
PostgreSQL container.

## LLM credentials

Direct browser tools (`browser_navigate`, `browser_get_state`, and
`browser_get_html`) work without an LLM. `browser_extract_content` and
`retry_with_browser_use_agent` use Browser Use's own LLM configuration; they do
not inherit Open WebUI's selected model. Browser Use is configured to call
OpenRouter directly with GPT-6 Luna:

```sh
OPENAI_BASE_URL=https://openrouter.ai/api/v1
OPENAI_API_KEY=<OpenRouter API key>
BROWSER_USE_LLM_MODEL=openai/gpt-6-luna
```

The OpenRouter key is stored only in the local, untracked `.env`; do not use the
MetaMCP or Open WebUI API key here. Extraction makes a separate OpenRouter
request, so it does not consume OpenCode Go quota or use that connection's
session header.

Then recreate the service:

```sh
docker compose up -d
```

Never commit `.env` or put API keys in this README.

## Operations

```sh
docker compose config --quiet
docker compose up -d --build
docker compose ps
docker compose logs -f
```

The browser runs headlessly with Browser Use's security features enabled. Review
the destinations and effects of browser actions; this service can access the
internet and should only be exposed through a trusted, authenticated MetaMCP
namespace.
