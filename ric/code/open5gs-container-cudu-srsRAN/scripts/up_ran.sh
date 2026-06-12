#!/bin/bash
# Script para iniciar a RAN srsRAN split-8 + srsUE
# Uso: ./scripts/up_ran.sh
# Requer: CORE ja rodando (./scripts/up_core.sh ou ./scripts/up.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Iniciando RAN srsRAN split-8 (CU/DU + srsUE)"
echo "=========================================="
echo ""

if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker nao esta rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose nao esta disponivel. Instale Docker Compose plugin."
    exit 1
fi

if ! docker compose ps amf 2>/dev/null | grep -q "Up"; then
    echo "CORE nao detectado. Iniciando CORE..."
    docker compose up -d mongodb nrf scp amf smf ausf udm udr pcf nssf upf-a upf-b dn webui
    echo "Aguardando CORE iniciar..."
    sleep 25
fi

if ! docker image inspect "${SRSRAN_UE_IMAGE:-srsue:latest}" > /dev/null 2>&1; then
    echo ""
    echo "ERRO: imagem do srsUE nao encontrada (${SRSRAN_UE_IMAGE:-srsue:latest})."
    echo "Construa antes com: ./scripts/build-srsue.sh"
    exit 1
fi

echo ""
echo "Garantindo subscriber do srsUE no MongoDB..."
"$SCRIPT_DIR/add-subscriber.sh"

echo ""
echo "Iniciando CU/DU split-8 (ZMQ)..."
docker rm -f srsran-cu-du-containerized > /dev/null 2>&1 || true
docker compose --profile e2e up -d srsran-cu-du

echo "Aguardando CU/DU anunciar radio ZMQ..."
sleep 12

echo "Iniciando srsUE apos a DU..."
docker compose --profile e2e up -d --force-recreate srsran-ue

echo ""
echo "Aguardando RAN iniciar..."
sleep 10

echo ""
echo "Status da RAN CU/DU:"
docker compose --profile e2e ps srsran-cu-du srsran-ue

echo ""
echo "Dicas:"
echo "  - Logs CU/DU: docker compose --profile e2e logs -f srsran-cu-du"
echo "  - Logs srsUE: docker compose --profile e2e logs -f srsran-ue"
echo "  - Interface UE: docker exec srsran-ue-containerized ip addr show tun_srsue"
echo "  - Teste E2E: ./scripts/test-srsue-e2e.sh"
echo ""
echo "=========================================="
echo "RAN split-8 iniciada!"
echo "=========================================="
echo ""
