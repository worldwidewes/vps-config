# n8n AI Assistant → OpenCode Go

Makes the n8n "AI Assistant" run on the OpenCode Go subscription
(`https://opencode.ai/zen/go/v1`).

## Current configuration

| Setting | Value |
| --- | --- |
| Provider (credential type) | `openAiApi` (OpenAI-compatible endpoint) |
| Base URL | `https://opencode.ai/zen/go/v1` |
| API key | from the OpenCode credential store (`opencode-go`) |
| Custom header | `x-opencode-session: n8n-assistant` (required by OpenCode Go) |
| Model | `deepseek-v4.1-flash` |

The Assistant stores its model as an **instance credential** named
`n8n Assistant model` plus `modelName` in the `instanceAi.settings` row.
Without `x-opencode-session` OpenCode Go returns `400 MissingSessionID`
(any non-empty identifier works as the value).

## Model compatibility (important)

n8n auto-selects the **Responses API** for custom OpenAI-compatible
endpoints. OpenCode Go models differ in which protocol they accept:

| Works with n8n (Responses or both) | Chat-only (n8n picks Responses → fails) |
| --- | --- |
| `deepseek-v4.1-flash`, `deepseek-v4-pro`, `deepseek-v4-flash` | `kimi-k2.7-code`, `glm-5.3` |
| `gpt-6-luna`, `gpt-5.6-luna`, `grok-4.7` (Responses-only) | `qwen3.8-max`, `minimax-m3`, `space-bunny` |

Recommended: **`deepseek-v4.1-flash`** (solid tool-calling, supports both
protocols). `gpt-6-luna` works but was observed producing a malformed
`load_skill` tool call (a degenerate 10-minute generation), so it is not the
default here. Chat-only models need a code tweak to force `/chat/completions`.

## Changing the model / account

Nothing is hardcoded in n8n — the API key, base URL, header and model all live
in n8n's DB (encrypted credential + settings). The script is the safe way to
change them:

```bash
sudo /root/n8n-opencode-go/set-model.sh --dry-run                   # preview
sudo /root/n8n-opencode-go/set-model.sh deepseek-v4-pro             # change model
sudo /root/n8n-opencode-go/set-model.sh --api-key oc_sk_xxx         # another account/key
sudo /root/n8n-opencode-go/set-model.sh --api-key-file /root/my.key  # key from file
sudo /root/n8n-opencode-go/set-model.sh --base-url https://host/v1 --api-key sk-xxx
sudo /root/n8n-opencode-go/set-model.sh --session my-session-id     # header value
```

The script stops n8n, backs up the DB to `/root/n8n-backups/<timestamp>/`,
writes the credential + `modelName`, and starts n8n (~1-2 min). Add
`--no-restart` to only write, `--dry-run` to preview.

**The UI cannot manage this.** The "Connect a model" dialog builds the
credential from `{ apiKey, url }` only — it has no custom-header field — so
saving it **removes `x-opencode-session`** and breaks the Assistant. Change
models/accounts with the script; re-run it if the dialog is saved by accident.
(The dialog only preserves the header when the model is env-managed via
`N8N_INSTANCE_AI_*`, which this setup is not.)

## Troubleshooting

- **"Something went wrong before I could finish that response"** after a big
  assistant action → usually the model produced an invalid tool call. Try a
  stronger/other model (see compatibility table).
- **`sandbox not found`** after a full stack restart → restart just n8n:
  `docker restart n8n-with-ai-assistant-v7zl-n8n-1`.
- **`400 MissingSessionID`** → header was lost (UI save). Re-run `set-model.sh`.

See `OPENCODE-GO-N8N.md` for the full technical write-up.
