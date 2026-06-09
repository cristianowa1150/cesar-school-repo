#!/usr/bin/env bash
# Inicia o srsDU usando o perfil Open Fronthaul (ru_ofh) com RU emulada (ru_emulator).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

CFG="${1:-du-ofh-ru-emulator.yml}"

if ! docker ps --format '{{.Names}}' | grep -qx srsran-du; then
  echo "Erro: o contentor srsran-du não está em execução."
  echo "  Suba o stack: ./scripts/up.sh"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx srsran-ru; then
  echo "Erro: o contentor srsran-ru não está em execução."
  echo "  Suba o stack: ./scripts/up.sh"
  exit 1
fi

echo "Dica: confirme MACs do link OFH antes (opcional): ./scripts/verify-ofh.sh"
echo "Iniciando srsDU (ru_ofh) com ${CFG}..."
exec docker exec -it srsran-du srsdu -c "/etc/srsran/${CFG}"

