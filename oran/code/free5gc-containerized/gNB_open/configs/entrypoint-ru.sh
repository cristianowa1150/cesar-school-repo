#!/bin/sh
set -eu

BIN="$(command -v ru_emulator || true)"
[ -x "${BIN:-}" ] || { echo "FATAL: ru_emulator não encontrado (imagem srsRAN incompleta?)"; exit 127; }

if [ "${RU_AUTO_START:-0}" = "0" ]; then
  echo "[info] RU_AUTO_START=0: ru_emulator NÃO foi iniciado (arranque manual)."
  echo "  No host:  ./scripts/start-ru-emulator.sh"
  echo "  ou:       docker exec -it srsran-ru ru_emulator -c /etc/srsran/ru_emulator.yml"
  exec tail -f /dev/null
fi

exec "$BIN" -c /etc/srsran/ru_emulator.yml

