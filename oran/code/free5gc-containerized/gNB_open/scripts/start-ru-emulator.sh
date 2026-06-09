#!/usr/bin/env bash
# Inicia o RU emulator (Open Fronthaul) no container srsran-ru.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! docker ps --format '{{.Names}}' | grep -qx srsran-ru; then
  echo "Erro: o contentor srsran-ru não está em execução."
  echo "  Suba o stack: ./scripts/up.sh"
  exit 1
fi

echo "Iniciando RU emulator (ru_emulator -c /etc/srsran/ru_emulator.yml)..."
exec docker exec -it srsran-ru ru_emulator -c /etc/srsran/ru_emulator.yml

