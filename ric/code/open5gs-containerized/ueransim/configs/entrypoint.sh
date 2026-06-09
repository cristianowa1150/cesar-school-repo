#!/bin/bash
set -eu

# Binários variam por imagem:
# - gradiant/ueransim: /usr/local/bin/nr-gnb, /usr/local/bin/nr-ue
# - outras: cwd com ./nr-gnb ou /ueransim/bin/...
resolve_nr_bin() {
  local base="$1"
  for path in "/usr/local/bin/${base}" "./${base}" "/ueransim/bin/${base}"; do
    if [ -x "$path" ]; then
      printf '%s' "$path"
      return 0
    fi
  done
  return 1
}

if [ -z "${GNB_BIN:-}" ]; then
  GNB_BIN="$(resolve_nr_bin nr-gnb)" || { echo "[entrypoint] nr-gnb não encontrado"; exit 1; }
fi
if [ -z "${UE_BIN:-}" ]; then
  UE_BIN="$(resolve_nr_bin nr-ue)" || { echo "[entrypoint] nr-ue não encontrado"; exit 1; }
fi
echo "[entrypoint] GNB_BIN=$GNB_BIN UE_BIN=$UE_BIN"

echo "[entrypoint] starting gNB..."
$GNB_BIN -c /ueransim/config/gnb.yaml &
GNB_PID=$!

sleep 2

echo "[entrypoint] starting UE..."
$UE_BIN -c /ueransim/config/ue.yaml &
UE_PID=$!

# Mantém o container vivo e propaga sinais
trap "kill $GNB_PID $UE_PID; exit 0" INT TERM
wait $GNB_PID $UE_PID
