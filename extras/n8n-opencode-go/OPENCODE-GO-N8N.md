# Running n8n's AI Assistant on an OpenCode Go subscription

How to make n8n's built-in **AI Assistant** (the `instance-ai` module) talk to
OpenCode Go instead of a stock provider, and why the normal UI can't do it.

- **n8n version:** 2.40.7
- **Container:** `n8n-with-ai-assistant-v7zl-n8n-1`
- **Image:** `docker.n8n.io/n8nio/n8n`
- **Data volume:** `/var/lib/docker/volumes/n8n-with-ai-assistant-v7zl_n8n_data/_data`
- **OpenCode Go endpoint:** `https://opencode.ai/zen/go/v1`
- **Result:** Assistant runs on `deepseek-v4.1-flash` (changeable) via OpenCode Go.

---

## 1. The problem: OpenCode Go requires a required header the UI can't set

OpenCode Go is OpenAI-compatible, **but every request must carry a session
header**, otherwise it rejects the call:

```
$ curl -H "Authorization: Bearer $KEY" -d '{...}' https://opencode.ai/zen/go/v1/chat/completions
HTTP 400
{"type":"error","error":{"type":"MissingSessionID",
 "message":"Request is missing x-opencode-session and cannot be routed efficiently."}}
```

With the header it works:

```
$ curl -H "Authorization: Bearer $KEY" -H 'x-opencode-session: n8n-assistant' -d '{...}' ...
HTTP 200
```

The value can be **any non-empty identifier** (`n8n-assistant`, a session id,
etc.). It's used by the gateway for session affinity/routing.

### Why the "Connect a model" dialog can't do it

The Assistant's **Connect a model** dialog only renders:

- Provider
- API key
- Base URL (for the "Self-hosted or OpenAI-compatible endpoint" provider)
- Model

There is **no field for a custom header**. Internally n8n *does* support a
custom header on its OpenAI credential (`OpenAiApi.credentials.js`):

```js
// n8n-nodes-base/.../credentials/OpenAiApi.credentials.js
{
  displayName: 'Add Custom Header', name: 'header', type: 'boolean', default: false,
},
{ displayName: 'Header Name',  name: 'headerName',  ... show: { header: [true] } },
{ displayName: 'Header Value', name: 'headerValue', ... show: { header: [true] } },
```

…and the Assistant backend forwards it. From
`n8n/dist/modules/instance-ai/instance-ai-settings.service.js`:

```js
function modelCredentialHeaders(credentialType, data) {
    const headers = {};
    if ((credentialType === 'openAiApi' || credentialType === 'anthropicApi') &&
        data.header === true &&
        typeof data.headerName === 'string' &&
        typeof data.headerValue === 'string') {
        const headerName = data.headerName.trim();
        if (headerName) headers[headerName] = data.headerValue;
    }
    return Object.keys(headers).length ? headers : undefined;
}

buildModelConfig(credentialType, data, modelName) {
    ...
    const headers = modelCredentialHeaders(credentialType, data);
    return { id, url: baseUrl, ...(apiKey ? { apiKey } : {}), ...(headers ? { headers } : {}) };
}
```

So the fix is to put `header/headerName/headerValue` on the **credential data**
that the Assistant uses. The dialog doesn't expose those fields, so we write
them directly.

> **Critical caveat:** saving the **Connect a model** dialog sends a
> `modelConnection`, which **replaces the credential data** and therefore
> **removes the hidden header** — breaking the Assistant again. Change models
> with the script (§6) instead.

---

## 2. Where n8n stores the Assistant's model

Two rows in the n8n SQLite database
(`.../n8n_data/_data/database.sqlite`):

1. **The credential** — `credentials_entity`, name `n8n Assistant model`,
   `usageScope = 'instance'`, `type` normally one of
   `INSTANCE_AI_MODEL_CREDENTIAL_TYPES` (`openAiApi`, `anthropicApi`, …).
   Its `data` column is **encrypted JSON** of the credential fields.

2. **The assignment + model name**
   - `instance_credential_assignment`: `credentialUseId = 'instance-ai:model'`
     points at the credential id.
   - `settings` row `key = 'instanceAi.settings'` holds `modelName`
     (the effective admin model).

The model id sent to the provider is built as `<provider>/<modelName>` where
`<provider>` comes from `CREDENTIAL_TO_MODEL_PROVIDER[type]` — `openAiApi` →
`openai`, so the runtime id is `openai/gpt-6-luna`.

---

## 3. Encryption format used for `credentials_entity.data`

n8n's `CipherAes256CBC` (`n8n-core/dist/encryption/aes-256-cbc.js`) is
OpenSSL-compatible **EVP_BytesToKey (MD5) + AES-256-CBC**, output base64,
prefixed with the bytes `Salted__`:

```
salt   = 8 random bytes
key||iv = MD5(password) || MD5(MD5(password)||password) || MD5(MD5^2||password)
   where password = instanceKey.encode('latin-1') + salt
blob   = base64( "Salted__" + salt + AES-256-CBC-PKCS7(plaintext) )
```

`instanceKey` is `encryptionKey` from
`.../n8n_data/_data/config` (e.g. `"Yho6e2TLUeXt3d/MpimyTFa8zjYQofGc"`).
The same format is used for reading and writing, so it can be produced with a
few lines of Python (see `set-model.sh`, which embeds this).

Credentials can also carry a key-id prefix (V2 keys), but this instance uses
the legacy single-key format, which `Cipher.decryptV2` still supports.

---

## 4. Exactly what was changed

The Assistant credential `wmBYWmuKW18jdOqC` ("n8n Assistant model") was
rewritten from `openRouterApi` to `openAiApi` with this plaintext JSON:

```json
{
  "apiKey": "oc_sk_…",
  "url": "https://opencode.ai/zen/go/v1",
  "header": true,
  "headerName": "x-opencode-session",
  "headerValue": "n8n-assistant"
}
```

and `settings['instanceAi.settings'].modelName` was set to `deepseek-v4.1-flash`.

The `oc_sk_…` API key was read from **OpenCode's own credential database**
(`~/.local/share/opencode/opencode.db`, integration `opencode-go`, label
"OpenCode Go") — *not* from Open WebUI.

Procedure (all done on the host as root, with n8n stopped so SQLite wasn't
being written concurrently):

```bash
docker stop n8n-with-ai-assistant-v7zl-n8n-1
# back up database.sqlite, -wal, -shm and config
# python: checkpoint WAL, encrypt the JSON above, then:
#   UPDATE credentials_entity SET type='openAiApi', data=<encrypted>, updatedAt=<now>
#     WHERE id='wmBYWmuKW18jdOqC';
#   UPDATE settings SET value=json_set(value,'$.modelName','gpt-6-luna')
#     WHERE key='instanceAi.settings';
docker start n8n-with-ai-assistant-v7zl-n8n-1
```

No n8n source files were patched — this uses n8n's existing, supported
credential-header feature. n8n just needs the fields written where its own UI
can't reach them.

---

## 5. Verification performed

Run **inside the n8n container**, through n8n's own model factory, with the
exact config the Assistant builds:

```js
const { createModel } = require('@n8n/agents/dist/runtime/model/model-factory.js');
const { generateText, streamText } = require('ai');
const cfg = { id: 'openai/gpt-6-luna', url: 'https://opencode.ai/zen/go/v1',
              apiKey: OC_KEY, headers: { 'x-opencode-session': 'n8n-assistant' } };
await generateText({ model: createModel(cfg), prompt: 'Reply with exactly: PONG' });
// -> "PONG"
// streaming (what the chat uses) -> "Hello"
```

Sandbox workspace path (Assistant requires it):

```
SANDBOX_CMD: {"success":true,"exitCode":0,"stdout":"ok\n"}
```

Both passed for `deepseek-v4.1-flash`, `deepseek-v4-pro` and `gpt-6-luna`.

### Model / protocol compatibility (important)

n8n auto-selects the **Responses API** for custom OpenAI-compatible endpoints.
OpenCode Go exposes different protocols per model, and a chat-only model fails
because n8n does not treat `ModelProtocolUnsupported` as "fall back to chat":

| Works with n8n | Chat-only (fails on Responses) |
| --- | --- |
| `deepseek-v4.1-flash`, `deepseek-v4-pro`, `deepseek-v4-flash` (both) | `kimi-k2.7-code`, `glm-5.3`, `qwen3.8-max`, `minimax-m3`, `space-bunny` |
| `gpt-6-luna`, `gpt-5.6-luna`, `grok-4.7` (Responses-only) | |

`gpt-6-luna` additionally produced a **malformed `load_skill` tool call** on a
real run (a degenerate ~10-minute generation whose tool arguments contained the
model's own commentary), which is why `deepseek-v4.1-flash` is the default here.
Chat-only models can be used by patching `buildModelConfig` in
`instance-ai-settings.service.js` to pass through `apiStyle: 'chat'` and
setting it on the credential — not applied by default.

---

## 6. Changing the model safely

Use the helper script (keeps the header, re-reads the API key, backs up first):

```bash
sudo /root/n8n-opencode-go/set-model.sh                 # default: deepseek-v4.1-flash
sudo /root/n8n-opencode-go/set-model.sh deepseek-v4-pro
sudo /root/n8n-opencode-go/set-model.sh gpt-6-luna
sudo /root/n8n-opencode-go/set-model.sh --api-key oc_sk_xxx           # another account
sudo /root/n8n-opencode-go/set-model.sh --api-key-file /root/my.key
sudo /root/n8n-opencode-go/set-model.sh --base-url https://host/v1 --api-key sk-xxx
sudo /root/n8n-opencode-go/set-model.sh --session my-session-id       # header value
sudo /root/n8n-opencode-go/set-model.sh --dry-run       # preview only
```

Nothing is hardcoded in n8n: the key, base URL, header and model are stored in
n8n's DB. By default the script reads the key from the local OpenCode credential
store, but `--api-key` / `--api-key-file` let you point it at any OpenCode Go
account (or any OpenAI-compatible endpoint).

Use only models that work with n8n's Responses-first behavior (see the
compatibility table in §5). `deepseek-v4.1-flash` is recommended.

It stops n8n, backs the DB up to `/root/n8n-backups/<timestamp>/`, writes the
credential + `modelName`, then starts n8n (~1–2 min to boot).

**Can I change the model from the menus?**
The **Connect a model** dialog will rewrite the credential and drop
`x-opencode-session`, so the Assistant will start failing with `MissingSessionID`.
If it happens, just re-run `set-model.sh` to restore the header. (The dialog
only leaves the credential alone when the model is controlled by
`N8N_INSTANCE_AI_*` env vars, which this setup doesn't use.)

Some `opencode-go` models: `gpt-6-luna`, `gpt-5.6-luna`, `deepseek-v4.1-flash`,
`deepseek-v4-pro`, `kimi-k2.7-code`, `glm-5.3`, `grok-4.7`, `qwen3.8-max`,
`minimax-m3`, `space-bunny`, `mimo-v2.6-pro`, …

---

## 7. Troubleshooting

**"Something went wrong before I could finish that response" / `sandbox not found`**
The Assistant runs tools in a sandbox. After a full stack restart the sandbox
container can be gone while a stale id is cached. Restart just n8n:

```bash
docker restart n8n-with-ai-assistant-v7zl-n8n-1
```

**`400 MissingSessionID` from the model**
The `x-opencode-session` header was lost (usually by saving the UI dialog).
Re-run `set-model.sh`.

**API key rotated**
`set-model.sh` always re-reads the current key from the OpenCode DB, so just
re-run it.

**UI save drops the header**
Expected; the dialog has no header field. Re-run `set-model.sh`.

---

## 8. Files

| Path | Purpose |
| --- | --- |
| `/root/n8n-opencode-go/set-model.sh` | Re-apply/switch model, keeps the header |
| `/root/n8n-opencode-go/README.md` | Short usage notes |
| `/root/n8n-opencode-go/OPENCODE-GO-N8N.md` | This document |
| `/root/n8n-backups/<timestamp>/` | DB snapshots taken before each change |
