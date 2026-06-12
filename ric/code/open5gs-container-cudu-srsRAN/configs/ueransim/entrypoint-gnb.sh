#!/bin/bash
#
# Entrypoint do gNB (UERANSIM) para o compose principal.
#
# Executa o nr-gnb diretamente contra um gnb.yaml estático com IPs fixos.
# Como o UERANSIM faz bind pelos endereços IP declarados no YAML
# (ngapIp/gtpIp/linkIp), a ordem não-determinística de eth0/eth1 no Docker
# é irrelevante — isso elimina a instabilidade de NG Setup.
#
set -u

GNB_BIN="${GNB_BIN:-nr-gnb}"
GNB_CONFIG="${GNB_CONFIG:-/ueransim/gnb.yaml}"

echo "[gnb] aguardando AMF (NGAP) ficar acessível..."
sleep 3

echo "[gnb] iniciando nr-gnb com $GNB_CONFIG ..."
exec "$GNB_BIN" -c "$GNB_CONFIG"
