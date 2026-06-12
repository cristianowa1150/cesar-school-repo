#!/bin/bash
#
# Entrypoint do UE (UERANSIM) para o compose principal.
#
# Executa o nr-ue diretamente contra um ue.yaml estático (montado read-only).
# Não usa o templating da imagem (que tentava escrever no ue.yaml read-only).
#
# Após a sessão PDU subir (interface uesimtun0), define a rota default através
# do túnel, de modo que aplicativos no container alcancem a internet sem
# precisar de "ping -I uesimtun0".
#
set -u

UE_BIN="${UE_BIN:-nr-ue}"
UE_CONFIG="${UE_CONFIG:-/ueransim/ue.yaml}"

echo "[ue] aguardando o gNB ficar disponível..."
sleep 5

echo "[ue] iniciando nr-ue com $UE_CONFIG ..."
"$UE_BIN" -c "$UE_CONFIG" &
UE_PID=$!

# Configura a rota default pelo túnel da sessão PDU assim que ele aparecer
(
    for _ in $(seq 1 120); do
        if ip link show uesimtun0 >/dev/null 2>&1; then
            UE_IP=$(ip -4 addr show uesimtun0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || true)
            if [ -n "${UE_IP:-}" ]; then
                ip route replace default dev uesimtun0 2>/dev/null || true
                echo "[ue] rota default configurada via uesimtun0 (UE IP: $UE_IP)"
                break
            fi
        fi
        sleep 2
    done
) &

trap 'kill "$UE_PID" 2>/dev/null; exit 0' INT TERM
wait "$UE_PID"
