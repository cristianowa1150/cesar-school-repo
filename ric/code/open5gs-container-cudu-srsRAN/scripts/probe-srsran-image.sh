#!/bin/bash
# Validate whether an srsRAN image can run this lab.

set -euo pipefail

IMAGE="${1:-${SRSRAN_STRICT_CU_DU_IMAGE:-open5gs-srsran-cudu-zmq:latest}}"

echo "=========================================="
echo "Probe imagem srsRAN"
echo "=========================================="
echo "Imagem: $IMAGE"
echo ""

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
    echo "ERRO: imagem nao encontrada localmente: $IMAGE"
    echo "Construa com: ./scripts/build-srsran-cudu-zmq.sh"
    exit 1
fi

docker run --rm "$IMAGE" sh -lc '
set -eu

for bin in srscu srsdu; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ERRO: binario ausente: $bin"
        exit 10
    fi
    echo "OK: $bin encontrado em $(command -v "$bin")"
done

if command -v gnb_split_8 >/dev/null 2>&1; then
    echo "OK: gnb_split_8 encontrado em $(command -v gnb_split_8)"
elif command -v gnb >/dev/null 2>&1; then
    echo "OK: gnb encontrado em $(command -v gnb)"
else
    echo "Aviso: gnb/gnb_split_8 nao encontrado; modo strict-cudu ainda pode funcionar."
fi

if ldconfig -p 2>/dev/null | grep -qi zmq || find /usr /lib -iname "*zmq*" -print -quit 2>/dev/null | grep -q .; then
    echo "OK: bibliotecas ZMQ detectadas"
else
    echo "ERRO: ZMQ nao detectado na imagem"
    exit 11
fi

echo "OK: imagem apta para tentativa strict-cudu"
'
