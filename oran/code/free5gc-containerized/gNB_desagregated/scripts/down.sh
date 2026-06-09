#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Encerrando RAN aberto (CU + DU)..."
docker compose down
echo "Pronto. A rede free5gc-privnet permanece se o core ainda estiver ativo."
