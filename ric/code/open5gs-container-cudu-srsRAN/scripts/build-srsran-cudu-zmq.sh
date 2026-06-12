#!/bin/bash
# Build local srsRAN Project image with srscu/srsdu and ZeroMQ enabled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

IMAGE="${SRSRAN_STRICT_CU_DU_IMAGE:-open5gs-srsran-cudu-zmq:latest}"
REF="${SRSRAN_PROJECT_REF:-release_25_04}"
REPO="${SRSRAN_PROJECT_REPO:-https://github.com/srsran/srsRAN_Project.git}"

echo "=========================================="
echo "Build srsRAN Project CU/DU + ZMQ"
echo "=========================================="
echo "Imagem: $IMAGE"
echo "Repositorio: $REPO"
echo "Ref: $REF"
echo ""

docker build \
    --build-arg "SRSRAN_PROJECT_REPO=$REPO" \
    --build-arg "SRSRAN_PROJECT_REF=$REF" \
    -t "$IMAGE" \
    -f docker/srsran-cudu-zmq/Dockerfile \
    docker/srsran-cudu-zmq

echo ""
"$SCRIPT_DIR/probe-srsran-image.sh" "$IMAGE"

echo ""
echo "Imagem pronta: $IMAGE"
