#!/bin/sh
set -eu

echo "[UERANSIM] EntryPoint combinado (gNB + UE)"

# Pequena função de log com timestamp
log() {
  echo "[UERANSIM][$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "Iniciando gNB..."
/entrypoint.sh gnb &
GNB_PID=$!

log "Aguardando gNB estabilizar antes de iniciar UE..."
sleep 5

log "Iniciando UE..."
/entrypoint.sh ue &
UE_PID=$!

log "gNB PID=${GNB_PID}, UE PID=${UE_PID}"

# Espera os dois processos terminarem e propaga o código de saída do UE
wait "$GNB_PID"
GNB_EXIT=$? || true

wait "$UE_PID"
UE_EXIT=$? || true

log "gNB terminou com código ${GNB_EXIT}, UE terminou com código ${UE_EXIT}."

if [ "${UE_EXIT}" -ne 0 ]; then
  exit "${UE_EXIT}"
fi

exit "${GNB_EXIT}"


