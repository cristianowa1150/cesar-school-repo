#!/bin/bash
# Script para parar o RAN (UERANSIM - gNB + UE)
# Uso: ./scripts/down_ran.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
UERANSIM_DIR="$PROJECT_DIR"

echo "=========================================="
echo "Parando RAN/UERANSIM (gNB + UE)"
echo "=========================================="
echo ""

if [ ! -d "$UERANSIM_DIR" ]; then
    echo "ERRO: Diretório do UERANSIM não encontrado em: $UERANSIM_DIR"
    exit 1
fi

cd "$UERANSIM_DIR"
docker compose down

echo ""
echo "=========================================="
echo "RAN parado com sucesso!"
echo "=========================================="
echo ""
echo "💡 Para reiniciar: ./scripts/up_ran.sh"
echo "   (Certifique-se de que o CORE está rodando: ./scripts/up_core.sh)"
echo ""
