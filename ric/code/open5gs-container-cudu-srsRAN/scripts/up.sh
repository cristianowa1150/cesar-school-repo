#!/bin/bash
# Script para iniciar todo o laboratório Open5GS containerizado
# Uso: ./scripts/up.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Iniciando Laboratório Open5GS Containerizado"
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

echo "Iniciando serviços do CORE..."
docker compose up -d mongodb nrf scp amf smf ausf udm udr pcf nssf upf-a upf-b dn webui

echo ""
echo "Aguardando serviços iniciarem..."
sleep 15

echo ""
echo "Iniciando RAN desagregada..."
"$SCRIPT_DIR/up_ran.sh"

# Verificar status
echo ""
echo "Status dos serviços:"
docker compose --profile e2e ps

echo ""
echo "=========================================="
echo "Laboratório iniciado com sucesso!"
echo "=========================================="
echo ""
echo "📋 Scripts Disponíveis:"
echo "  - ./scripts/healthcheck.sh          - Verificação de saúde dos serviços"
echo "  - ./scripts/test-system-status.sh   - Verificação detalhada do sistema"
echo "  - ./scripts/test-srsue-e2e.sh      - Teste de conectividade E2E com srsUE"
echo "  - ./scripts/test_upf_failover.sh   - Teste de failover entre UPFs"
echo ""
echo "📝 Comandos Úteis:"
echo "  - Ver logs: docker compose logs -f <serviço>"
echo "  - Ver status: docker compose ps"
echo "  - Parar: ./scripts/down.sh"
echo ""
echo "⚠️  Notas Importantes:"
echo "  - Aguarde alguns segundos para todos os serviços iniciarem completamente"
echo "  - Execute './scripts/test-system-status.sh' para verificar o estado real do sistema"
echo "  - Se houver problema de 'AMF context not found', consulte a documentação"
echo ""
