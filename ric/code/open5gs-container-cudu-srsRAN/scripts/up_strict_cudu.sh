#!/bin/bash
# Start strict CU/DU split: srscu + srsdu + srsUE.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

IMAGE="${SRSRAN_STRICT_CU_DU_IMAGE:-open5gs-srsran-cudu-zmq:latest}"

echo "=========================================="
echo "Iniciando srsRAN CU/DU estrito"
echo "=========================================="
echo "Imagem CU/DU: $IMAGE"
echo ""

if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker nao esta rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose nao esta disponivel. Instale Docker Compose plugin."
    exit 1
fi

if ! docker image inspect "${SRSRAN_UE_IMAGE:-srsue:latest}" > /dev/null 2>&1; then
    echo "ERRO: imagem do srsUE nao encontrada (${SRSRAN_UE_IMAGE:-srsue:latest})."
    echo "Construa antes com: ./scripts/build-srsue.sh"
    exit 1
fi

"$SCRIPT_DIR/probe-srsran-image.sh" "$IMAGE"

if ! docker compose ps amf 2>/dev/null | grep -q "Up"; then
    echo ""
    echo "CORE nao detectado. Iniciando CORE..."
    docker compose up -d mongodb nrf scp amf smf ausf udm udr pcf nssf upf-a upf-b dn webui
    echo "Aguardando CORE iniciar..."
    sleep 25
fi

echo ""
echo "Garantindo subscriber do srsUE no MongoDB..."
"$SCRIPT_DIR/add-subscriber.sh"

echo ""
echo "Removendo RAN anterior..."
docker rm -f srsran-cu-containerized srsran-du-containerized srsran-cu-du-containerized srsran-ue-containerized > /dev/null 2>&1 || true

echo "Iniciando CU..."
docker compose --profile strict-cudu up -d srsran-cu
sleep 8

echo "Iniciando DU..."
docker compose --profile strict-cudu up -d srsran-du
sleep 12

echo "Iniciando srsUE..."
docker compose --profile strict-cudu up -d --force-recreate srsran-ue
sleep 10

echo ""
echo "Status strict-cudu:"
docker compose --profile strict-cudu ps srsran-cu srsran-du srsran-ue

echo ""
echo "Dicas:"
echo "  - Logs CU: docker compose --profile strict-cudu logs -f srsran-cu"
echo "  - Logs DU: docker compose --profile strict-cudu logs -f srsran-du"
echo "  - Logs srsUE: docker compose --profile strict-cudu logs -f srsran-ue"
echo "  - Teste E2E: ./scripts/test-srsue-e2e.sh"
echo ""
echo "strict-cudu iniciado. Se o UE nao registrar, verifique F1AP/NGAP nos logs."
