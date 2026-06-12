#!/bin/bash

# Script para corrigir a rota padrão do UE para usar a sessão PDU
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-16

set +e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

UE_SERVICE="ueransim-ue"
OGSTUN_GW="10.60.0.1"
PDU_INTERFACE="eth1"

echo "=========================================="
echo "Corrigir Rota Padrão do UE"
echo "=========================================="
echo ""

# Verificar se UE está rodando
if ! docker compose ps --format "{{.Service}}" 2>/dev/null | grep -q "^${UE_SERVICE}$"; then
    echo -e "${RED}❌ UE não está rodando${NC}"
    exit 1
fi

# Verificar se UE tem IP da sessão PDU
UE_IP=$(docker compose exec -T $UE_SERVICE ip addr show $PDU_INTERFACE 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
if [ -z "$UE_IP" ]; then
    echo -e "${RED}❌ UE não possui IP da sessão PDU na interface $PDU_INTERFACE${NC}"
    echo "   Certifique-se de que o UE está registrado e a sessão PDU está estabelecida"
    exit 1
fi

echo -e "${GREEN}✅ UE possui IP da sessão PDU: $UE_IP${NC}"
echo ""

# Verificar rota padrão atual
CURRENT_GW=$(docker compose exec -T $UE_SERVICE ip route show default 2>/dev/null | grep -oP 'via \K[\d.]+' | head -1 || echo "")
CURRENT_DEV=$(docker compose exec -T $UE_SERVICE ip route show default 2>/dev/null | grep -oP 'dev \K\w+' | head -1 || echo "")

echo "Rota padrão atual:"
if [ -n "$CURRENT_GW" ] && [ -n "$CURRENT_DEV" ]; then
    echo "  Gateway: $CURRENT_GW"
    echo "  Interface: $CURRENT_DEV"
    
    if [ "$CURRENT_GW" = "$OGSTUN_GW" ] && [ "$CURRENT_DEV" = "$PDU_INTERFACE" ]; then
        echo -e "${GREEN}✅ Rota padrão já está correta!${NC}"
        exit 0
    fi
else
    echo "  Nenhuma rota padrão encontrada"
fi
echo ""

# Verificar se gateway ogstun é acessível
echo "Verificando conectividade com gateway ogstun ($OGSTUN_GW)..."
if docker compose exec -T $UE_SERVICE ping -c 1 -W 1 $OGSTUN_GW >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Gateway ogstun acessível${NC}"
else
    echo -e "${YELLOW}⚠️  Gateway ogstun não acessível (pode ser normal se não houver sessão PDU ativa)${NC}"
fi
echo ""

# Remover rota padrão antiga
echo "Removendo rota padrão antiga..."
docker compose exec -T $UE_SERVICE ip route del default 2>/dev/null || true
sleep 1

# Adicionar rota padrão correta
echo "Configurando rota padrão para usar sessão PDU..."
if docker compose exec -T $UE_SERVICE ip route add default via $OGSTUN_GW dev $PDU_INTERFACE 2>&1; then
    echo -e "${GREEN}✅ Rota padrão configurada: default via $OGSTUN_GW dev $PDU_INTERFACE${NC}"
else
    echo -e "${RED}❌ Erro ao configurar rota padrão${NC}"
    exit 1
fi
echo ""

# Verificar nova rota
echo "Verificando nova rota padrão..."
NEW_GW=$(docker compose exec -T $UE_SERVICE ip route show default 2>/dev/null | grep -oP 'via \K[\d.]+' | head -1 || echo "")
NEW_DEV=$(docker compose exec -T $UE_SERVICE ip route show default 2>/dev/null | grep -oP 'dev \K\w+' | head -1 || echo "")

if [ "$NEW_GW" = "$OGSTUN_GW" ] && [ "$NEW_DEV" = "$PDU_INTERFACE" ]; then
    echo -e "${GREEN}✅ Rota padrão corrigida com sucesso!${NC}"
    echo ""
    echo "Nova rota padrão:"
    docker compose exec -T $UE_SERVICE ip route show default
    echo ""
    echo "Testando conectividade..."
    if docker compose exec -T $UE_SERVICE ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Conectividade funcionando através da sessão PDU!${NC}"
    else
        echo -e "${YELLOW}⚠️  Conectividade não funcionou (pode precisar de mais tempo)${NC}"
    fi
else
    echo -e "${RED}❌ Falha ao verificar nova rota padrão${NC}"
    exit 1
fi

