#!/bin/sh
set -eu

# Ajuste paths conforme a sua imagem:
# - alguns builds têm "nr-gnb"/"nr-ue"
# - outros têm "gnb"/"ue"
# - outros instalam em /ueransim/bin
#
# Descobrir rápido:
# docker run --rm -it ueransim:latest sh -lc 'ls -R / | grep -iE "nr-gnb|nr-ue|ueransim" | head'

GNB_BIN="${GNB_BIN:-nr-gnb}"
UE_BIN="${UE_BIN:-nr-ue}"

echo "[entrypoint] starting gNB..."
$GNB_BIN -c /etc/ueransim/gnb.yaml &
GNB_PID=$!

sleep 2

echo "[entrypoint] starting UE..."
$UE_BIN -c /etc/ueransim/ue.yaml &
UE_PID=$!

# Quando o uesimtun0 subir (sessão PDU), encaminha o tráfego do container pelo
# túnel 5G. As rotas on-link de N2/N3 não dependem da default, então o gNB
# continua a falar com AMF e UPF normalmente.
(
  for _ in $(seq 1 60); do
    if ip link show uesimtun0 >/dev/null 2>&1; then
      ip route replace default dev uesimtun0 && \
        echo "[entrypoint] rota default via uesimtun0 configurada"
      break
    fi
    sleep 1
  done
) &

# Mantém o container vivo e propaga sinais
trap "kill $GNB_PID $UE_PID; exit 0" INT TERM
wait $GNB_PID $UE_PID
