#!/bin/bash
# Script para parar o CORE Open5GS (SBI)
# Uso: ./scripts/down_core.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Parando CORE Open5GS (SBI)"
echo "=========================================="
echo ""

docker compose down

echo ""
echo "=========================================="
echo "CORE parado com sucesso!"
echo "=========================================="
echo ""
echo "💡 Para reiniciar: ./scripts/up_core.sh"
echo "   (O RAN, se estiver rodando, continua ativo. Para pará-lo: ./scripts/down_ran.sh)"
echo ""
