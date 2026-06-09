#!/bin/bash
# Script para iniciar apenas os RANs (UERANSIM + srsRAN gNB)
# Uso: ./scripts/up_ran.sh
# Requer: CORE já rodando (./scripts/up_core.sh ou ./scripts/up.sh)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Iniciando RAN (UERANSIM + srsRAN gNB)"
echo "=========================================="
echo ""

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose não está disponível. Instale Docker Compose plugin."
    exit 1
fi

# Se CORE não estiver rodando, inicia primeiro
if ! docker compose ps amf 2>/dev/null | grep -q "Up"; then
    echo "CORE não detectado. Iniciando CORE..."
    docker compose up -d mongodb nrf scp amf smf ausf udm udr pcf nssf upf-a upf-b dn webui
    echo "Aguardando CORE iniciar..."
    sleep 25
fi

echo ""
echo "Iniciando UERANSIM split (gNB + UE)..."
docker compose up -d ueransim-gnb ueransim-ue

# ----------------------------------------------------------------------------
# srsRAN (5G SA via ZMQ): a imagem do UE (srsue:latest) é construída localmente
# a partir do fonte srsRAN_4G. Como ZMQ é sensível à ordem, o gNB deve subir e
# começar a transmitir ANTES do UE; reiniciar apenas um lado dessincroniza o ZMQ.
# ----------------------------------------------------------------------------
if docker image inspect "${SRSRAN_UE_IMAGE:-srsue:latest}" >/dev/null 2>&1; then
    echo ""
    echo "Iniciando srsRAN gNB (ZMQ)..."
    docker compose --profile srsran up -d srsran-gnb

    echo "Aguardando gNB srsRAN ficar pronto (ZMQ)..."
    sleep 12

    echo "Iniciando srsRAN UE (ZMQ) após o gNB..."
    docker compose --profile srsran up -d --force-recreate srsran-ue
else
    echo ""
    echo "  ⚠ Imagem do srsUE não encontrada (${SRSRAN_UE_IMAGE:-srsue:latest})."
    echo "    Construa antes com: ./scripts/build-srsue.sh"
    echo "    (a imagem do gNB padrão é aetherproject/srsran-gnb:rel-0.7.0)"
fi

echo ""
echo "Aguardando RAN iniciar..."
sleep 10

echo ""
echo "Status dos RANs:"
docker compose --profile srsran ps ueransim-gnb ueransim-ue srsran-gnb srsran-ue 2>/dev/null || docker compose ps ueransim-gnb ueransim-ue

echo ""
echo "Dicas:"
echo "  - UE adicional (ueransim standalone): docker compose -f ueransim/docker-compose.yaml up -d"
echo "  - Logs UERANSIM: docker compose logs -f ueransim-gnb ueransim-ue"
echo "  - Logs srsRAN gNB: docker exec srsran-gnb-containerized tail -f /tmp/gnb.log"
echo "  - Logs srsRAN UE:  docker compose logs -f srsran-ue"
echo "  - Interface UE UERANSIM: docker compose exec ueransim-ue ip addr show uesimtun0"
echo "  - Interface UE srsRAN:   docker exec srsran-ue-containerized ip addr show tun_srsue"
echo ""
echo "=========================================="
echo "RAN iniciado!"
echo "=========================================="
echo ""

