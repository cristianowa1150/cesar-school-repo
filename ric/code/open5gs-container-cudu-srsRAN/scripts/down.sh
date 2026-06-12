#!/bin/bash
# Script para parar todo o laboratório Open5GS containerizado
# Uso: ./scripts/down.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Parando Laboratório Open5GS Containerizado"
echo "=========================================="
echo ""

if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose não está disponível. Instale Docker Compose plugin."
    exit 1
fi

echo "Parando serviços do compose principal, incluindo perfis opcionais..."
COMPOSE_PROFILES=strict-cudu,e2e,tools docker compose down --remove-orphans

if [ -f "$PROJECT_DIR/ueransim/docker-compose.yaml" ]; then
    echo ""
    echo "Parando compose auxiliar do UERANSIM, se estiver ativo..."
    docker compose -f "$PROJECT_DIR/ueransim/docker-compose.yaml" down --remove-orphans || true
fi

echo ""
echo "Removendo containers remanescentes deste laboratório..."
containers=(
    open5gs-mongodb-containerized
    open5gs-nrf-containerized
    open5gs-scp-containerized
    open5gs-amf-containerized
    open5gs-smf-containerized
    open5gs-ausf-containerized
    open5gs-udm-containerized
    open5gs-udr-containerized
    open5gs-pcf-containerized
    open5gs-nssf-containerized
    open5gs-upf-containerized-a
    open5gs-upf-containerized-b
    open5gs-dn-containerized
    open5gs-webui-containerized
    ueransim-gnb-containerized
    ueransim-ue-containerized
    srsran-cu-containerized
    srsran-cu-cp-containerized
    srsran-cu-up-containerized
    srsran-cu-du-containerized
    srsran-du-containerized
    srsran-ue-containerized
    iperf3-server
    iperf3-client
)

for container in "${containers[@]}"; do
    if docker container inspect "$container" > /dev/null 2>&1; then
        docker rm -f "$container" > /dev/null
        echo "  removido: $container"
    fi
done

echo ""
echo "Removendo redes remanescentes deste laboratório..."
networks=(
    open5gs-container-cudu-srsran_net-sbi
    open5gs-container-cudu-srsran_net-n2
    open5gs-container-cudu-srsran_net-n3
    open5gs-container-cudu-srsran_net-n4
    open5gs-container-cudu-srsran_net-n6
    open5gs-container-cudu-srsran_net-air
    open5gs-container-cudu-srsran_net-zmq
    open5gs-container-cudu-srsran_net-f1c
    open5gs-container-cudu-srsran_net-f1u
)

for network in "${networks[@]}"; do
    if docker network inspect "$network" > /dev/null 2>&1; then
        docker network rm "$network" > /dev/null 2>&1 || true
        if docker network inspect "$network" > /dev/null 2>&1; then
            echo "  aviso: rede ainda em uso: $network"
        else
            echo "  removida: $network"
        fi
    fi
done

echo ""
echo "=========================================="
echo "Laboratório parado com sucesso!"
echo "=========================================="
echo ""
echo "💡 Para reiniciar: ./scripts/up.sh"
echo ""
