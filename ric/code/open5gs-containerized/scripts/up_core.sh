#!/bin/bash
# Script para iniciar apenas o CORE Open5GS (sem RAN/UERANSIM)
# Uso: ./scripts/up_core.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Iniciando CORE Open5GS (sem RAN)"
echo "=========================================="
echo ""

# Verificar se Docker está rodando
if ! docker info > /dev/null 2>&1; then
    echo "ERRO: Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi

# Verificar se docker compose está disponível
if ! command -v docker compose &> /dev/null; then
    echo "ERRO: docker compose não está disponível. Instale Docker Compose plugin."
    exit 1
fi

# Habilitar IP forwarding no host (necessário para roteamento)
echo "Habilitando IP forwarding no host..."
sudo sysctl -w net.ipv4.ip_forward=1 || true
sudo sysctl -w net.ipv6.conf.all.forwarding=1 || true

echo ""
echo "Iniciando serviços do CORE (MongoDB, NFs, UPFs, DN, WebUI)..."
docker compose up -d

echo ""
echo "Aguardando serviços iniciarem..."
sleep 15

echo ""
echo "Status dos serviços CORE:"
docker compose ps

echo ""
echo "=========================================="
echo "CORE Open5GS iniciado com sucesso!"
echo "=========================================="
echo ""
echo "Próximo passo sugerido:"
echo "  - Adicionar subscriber: ./scripts/add-subscriber.sh"
echo "  - Iniciar o RAN/UERANSIM: ./scripts/up_ran.sh"
echo ""

