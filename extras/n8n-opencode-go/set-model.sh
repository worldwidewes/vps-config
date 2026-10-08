#!/usr/bin/env bash
#
# Point the n8n "AI Assistant" at an OpenCode Go (or any OpenAI-compatible)
# endpoint, keeping the custom header that the n8n UI cannot set.
#
# Why a script? The n8n "Connect a model" dialog builds the credential from
# { apiKey, url } only. It has no custom-header field, so saving it *removes*
# x-opencode-session and breaks the Assistant. Nothing here is hardcoded in
# n8n -- the API key, base URL, header and model are just stored in n8n's DB.
#
# Usage:
#   ./set-model.sh                                   # default model
#   ./set-model.sh deepseek-v4-pro                   # change model
#   ./set-model.sh --api-key oc_sk_xxx               # use another account/key
#   ./set-model.sh --base-url https://host/v1 --api-key sk-xxx
#   ./set-model.sh --session my-session-id
#   ./set-model.sh --api-key-file /root/my.key
#   ./set-model.sh --dry-run
#
# Options:
#   --api-key KEY         OpenCode Go (or compatible) API key
#   --api-key-file PATH   read the API key from a file
#   --base-url URL        API base url (default: https://opencode.ai/zen/go/v1)
#   --session VALUE       value for the x-opencode-session header
#   --header-name NAME    custom header name (default: x-opencode-session)
#   --opencode-db PATH    DB to read the key from when --api-key is not given
#   --no-restart          write config but do not restart n8n
#   --dry-run             show what would change, write nothing
#
set -euo pipefail

CONTAINER="n8n-with-ai-assistant-v7zl-n8n-1"
DATA="/var/lib/docker/volumes/n8n-with-ai-assistant-v7zl_n8n_data/_data"
OPENCODE_DB="/root/.local/share/opencode/opencode.db"
BACKUP_ROOT="/root/n8n-backups"
BASE_URL="https://opencode.ai/zen/go/v1"
SESSION_ID="n8n-assistant"
HEADER_NAME="x-opencode-session"
MODEL="deepseek-v4.1-flash"
API_KEY=""
API_KEY_FILE=""
DRY_RUN=0
RESTART=1

while [ $# -gt 0 ]; do
  case "$1" in
    --api-key)        API_KEY="${2:?}"; shift 2 ;;
    --api-key-file)   API_KEY_FILE="${2:?}"; shift 2 ;;
    --base-url)       BASE_URL="${2:?}"; shift 2 ;;
    --session)        SESSION_ID="${2:?}"; shift 2 ;;
    --header-name)    HEADER_NAME="${2:?}"; shift 2 ;;
    --opencode-db)    OPENCODE_DB="${2:?}"; shift 2 ;;
    --no-restart)     RESTART=0; shift ;;
    --dry-run)        DRY_RUN=1; shift ;;
    -h|--help)        sed -n '2,30p' "$0"; exit 0 ;;
    -*)               echo "Unknown option: $1" >&2; exit 2 ;;
    *)                MODEL="$1"; shift ;;
  esac
done

if [ -n "$API_KEY_FILE" ]; then
  API_KEY="$(tr -d '\r\n' < "$API_KEY_FILE")"
fi

export MODEL BASE_URL SESSION_ID HEADER_NAME DATA OPENCODE_DB BACKUP_ROOT CONTAINER DRY_RUN RESTART API_KEY

python3 - <<'PY'
import base64, datetime, hashlib, json, os, shutil, sqlite3, subprocess, sys
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

DATA = os.environ['DATA']; OPENCODE_DB = os.environ['OPENCODE_DB']
BACKUP_ROOT = os.environ['BACKUP_ROOT']; CONTAINER = os.environ['CONTAINER']
MODEL = os.environ['MODEL']; BASE_URL = os.environ['BASE_URL']
SESSION_ID = os.environ['SESSION_ID']; HEADER_NAME = os.environ['HEADER_NAME']
DRY_RUN = os.environ['DRY_RUN'] == '1'; RESTART = os.environ['RESTART'] == '1'
API_KEY = os.environ['API_KEY'].strip()
CRED_ID = 'wmBYWmuKW18jdOqC'; SETTINGS_KEY = 'instanceAi.settings'

def g(salt, key):
    p = key.encode('latin-1') + salt
    h1 = hashlib.md5(p).digest(); h2 = hashlib.md5(h1 + p).digest()
    return h1 + h2, hashlib.md5(h2 + p).digest()

def encrypt(plaintext, key):
    salt = os.urandom(8); dk, iv = g(salt, key)
    enc = Cipher(algorithms.AES(dk), modes.CBC(iv)).encryptor()
    pad = 16 - (len(plaintext.encode()) % 16)
    ct = enc.update(plaintext.encode() + bytes([pad]) * pad) + enc.finalize()
    return base64.b64encode(b'Salted__' + salt + ct).decode()

def decrypt(data, key):
    raw = base64.b64decode(data); dk, iv = g(raw[8:16], key)
    dec = Cipher(algorithms.AES(dk), modes.CBC(iv)).decryptor()
    pt = dec.update(raw[16:]) + dec.finalize(); return pt[:-pt[-1]].decode()

enc_key = json.load(open(f'{DATA}/config'))['encryptionKey']

if not API_KEY:
    oc = sqlite3.connect(f'file:{OPENCODE_DB}?mode=ro&immutable=1', uri=True)
    row = oc.execute("SELECT value FROM credential WHERE integration_id='opencode-go'").fetchone()
    if not row:
        sys.exit('ERROR: no key given and no opencode-go credential found in the OpenCode DB.')
    API_KEY = json.loads(row[0])['key']; oc.close()
    src = f'OpenCode DB ({OPENCODE_DB})'
else:
    src = 'command line / file'

creds = {'apiKey': API_KEY, 'url': BASE_URL,
         'header': True, 'headerName': HEADER_NAME, 'headerValue': SESSION_ID}

print(f'Model          : {MODEL}')
print(f'Base URL       : {BASE_URL}')
print(f'Header         : {HEADER_NAME}: {SESSION_ID}')
print(f'API key        : {API_KEY[:8]}...{API_KEY[-4:]}  (from {src})')
if DRY_RUN:
    print('(dry run - nothing written)'); sys.exit(0)

ts = datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
bk = os.path.join(BACKUP_ROOT, ts); os.makedirs(bk, exist_ok=True)
for f in ('database.sqlite', 'database.sqlite-wal', 'database.sqlite-shm', 'config'):
    s = os.path.join(DATA, f)
    if os.path.exists(s): shutil.copy2(s, bk)
print(f'Backup         : {bk}')

if RESTART:
    print(f'Stopping       : {CONTAINER}'); subprocess.run(['docker', 'stop', CONTAINER], check=True)

con = sqlite3.connect(os.path.join(DATA, 'database.sqlite'))
con.execute('PRAGMA wal_checkpoint(TRUNCATE)')
cur = con.cursor()
now = datetime.datetime.now(datetime.UTC).strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]
cur.execute('UPDATE credentials_entity SET type=?, data=?, updatedAt=? WHERE id=?',
            ('openAiApi', encrypt(json.dumps(creds), enc_key), now, CRED_ID))
if cur.rowcount != 1:
    sys.exit(f'ERROR: model credential {CRED_ID} not found (changed in the UI?)')
cur.execute('SELECT value FROM settings WHERE key=?', (SETTINGS_KEY,))
s = json.loads(cur.fetchone()[0]); s['modelName'] = MODEL
cur.execute('UPDATE settings SET value=? WHERE key=?', (json.dumps(s), SETTINGS_KEY))
con.commit()
ctype = cur.execute('SELECT type FROM credentials_entity WHERE id=?', (CRED_ID,)).fetchone()[0]
con.close()
print(f'Credential type: {ctype}  (updated)')

if RESTART:
    print(f'Starting       : {CONTAINER}'); subprocess.run(['docker', 'start', CONTAINER], check=True)
    print('Done. n8n is restarting (~1-2 min). Then retry the Assistant chat.')
else:
    print('Written. Restart n8n for it to take effect.')
PY
