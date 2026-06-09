#!/bin/bash
# Build da imagem Docker srsUE (srsRAN 4G, ZMQ, 5G SA)
# Uso: ./scripts/build-srsue.sh [tag]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAG="${1:-srsue:latest}"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Build srsUE Docker image"
echo "=========================================="
echo "  Tag: $TAG"
echo "  Dockerfile: docker/srsue/Dockerfile"
echo ""

docker build -t "$TAG" -f docker/srsue/Dockerfile .

echo ""
echo "✅ Imagem construída: $TAG"
echo ""
echo "Teste rápido:"
echo "  docker run --rm -it --privileged -v \$(pwd)/configs/srsRAN:/config $TAG --ue.phy nr /config/ue.conf"
echo ""
echo "Nota: srsUE precisa do gNB (srsRAN Project) rodando e acessível via ZMQ."
echo "      device_args em ue.conf: rx_port=tcp://<gnb_host>:2000"
echo ""
