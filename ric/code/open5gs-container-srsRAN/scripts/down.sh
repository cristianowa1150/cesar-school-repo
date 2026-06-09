#!/bin/bash
# Script para parar todo o laboratório Open5GS containerizado
# Uso: ./scripts/down.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

echo "=========================================="
echo "Parando Laboratório Open5GS Containerizado"
echo "=========================================="
echo ""

# Parar todos os serviços
docker compose down

echo ""
echo "=========================================="
echo "Laboratório parado com sucesso!"
echo "=========================================="
echo ""
echo "💡 Para reiniciar: ./scripts/up.sh"
echo ""
