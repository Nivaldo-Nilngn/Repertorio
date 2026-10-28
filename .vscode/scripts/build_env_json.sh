#!/usr/bin/env bash
# build_env_json.sh
# Gera .env.json a partir do .env para uso com --dart-define-from-file
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENV_FILE="$ROOT_DIR/.env"
JSON_OUT="$ROOT_DIR/.env.json"

if [ ! -f "$ENV_FILE" ]; then
    echo "Erro: Arquivo .env não encontrado em $ENV_FILE. Copie .env.example para .env e preencha." >&2
    exit 1
fi

python3 -c "
import json, os, sys

env_file = '$ENV_FILE'
json_out = '$JSON_OUT'
data = {}

with open(env_file, 'r', encoding='utf-8') as f:
    for line in f:
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        if '=' in line:
            key, val = line.split('=', 1)
            data[key.strip()] = val.strip().strip('\"\'')

if not data:
    sys.exit('Nenhuma variável encontrada em .env')

with open(json_out, 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2)

print(f'.env.json gerado com {len(data)} variáveis em {json_out}')
"
