#!/bin/bash
# Script para iniciar apenas o RAN (UERANSIM) em compose separado
# Uso: ./scripts/up_ran.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UERANSIM_DIR="$PROJECT_DIR"

echo "=========================================="
echo "Iniciando RAN/UERANSIM (compose separado)"
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

# Verificar se diretório do UERANSIM existe
if [ ! -d "$UERANSIM_DIR" ]; then
    echo "ERRO: Diretório do UERANSIM não encontrado em: $UERANSIM_DIR"
    exit 1
fi

# Verificar se redes externas necessárias existem (criadas pelo compose do CORE)
echo "Verificando redes Docker compartilhadas (net-n2, net-n3)..."
for NET in open5gs-containerized_net-n2 open5gs-containerized_net-n3; do
    if ! docker network inspect "$NET" >/dev/null 2>&1; then
        echo "ERRO: Rede Docker '$NET' não encontrada."
        echo "      Certifique-se de iniciar o CORE primeiro com: ../scripts/up_core.sh"
        exit 1
    fi
done

cd "$UERANSIM_DIR"

echo ""
echo "Iniciando serviço UERANSIM..."
docker compose up -d

echo ""
echo "Aguardando UERANSIM ficar estável (running)..."
WAIT_SECS=10
for i in $(seq 1 "$WAIT_SECS"); do
    state="$(docker inspect -f '{{.State.Status}}' ueransim 2>/dev/null || echo missing)"
    if [ "$state" = "running" ]; then
        # Evita race: health/restart logo após "running"
        sleep 2
        state="$(docker inspect -f '{{.State.Status}}' ueransim 2>/dev/null || echo missing)"
        if [ "$state" = "running" ]; then
            break
        fi
    fi
    if [ "$i" -eq "$WAIT_SECS" ]; then
        echo "ERRO: Container ueransim não ficou running (último estado: $state)."
        echo "Últimas linhas do log:"
        docker logs --tail 80 ueransim 2>&1 || true
        exit 1
    fi
    sleep 1
done

echo ""
echo "Status do RAN/UERANSIM:"
docker exec ueransim ps

echo ""
echo "Dicas:"
echo "  - Ver logs: (no diretório ueransim) docker logs -f ueransim"
echo "  - Verificar se a interface uesimtun subiu:"
echo "      docker exec ueransim ip addr show uesimtun0"
echo ""
echo "=========================================="
echo "RAN/UERANSIM iniciado com sucesso!"
echo "=========================================="
echo ""

