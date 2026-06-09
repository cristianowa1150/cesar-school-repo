#!/bin/bash

# Script para forçar estabelecimento de sessão PDU
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
SMF_SERVICE="smf"
UPF_SERVICE="upf-a"

echo "=========================================="
echo "Forçar Estabelecimento de Sessão PDU"
echo "=========================================="
echo ""

# Verificar se UE está registrado
echo "1. Verificando registro do UE..."
if ! docker compose logs $UE_SERVICE 2>&1 | grep -q "MM-REGISTERED"; then
    echo -e "${RED}❌ UE não está registrado. Registre primeiro.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ UE está registrado${NC}"
echo ""

# Verificar se há IP atribuído
echo "2. Verificando IP do UE..."
UE_IP=$(docker compose exec -T $UE_SERVICE ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
if [ -z "$UE_IP" ]; then
    echo -e "${YELLOW}⚠️  UE não possui IP ainda${NC}"
else
    echo -e "${GREEN}✅ UE possui IP: $UE_IP${NC}"
fi
echo ""

# Verificar interface ogstun na UPF
echo "3. Verificando interface ogstun na UPF..."
if docker compose exec -T $UPF_SERVICE ip addr show ogstun >/dev/null 2>&1; then
    OGSTUN_IP=$(docker compose exec -T $UPF_SERVICE ip addr show ogstun 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
    if [ -n "$OGSTUN_IP" ]; then
        echo -e "${GREEN}✅ Interface ogstun existe: $OGSTUN_IP${NC}"
    else
        echo -e "${YELLOW}⚠️  Interface ogstun existe mas não tem IP${NC}"
    fi
else
    echo -e "${RED}❌ Interface ogstun não existe${NC}"
fi
echo ""

# Verificar associação PFCP
echo "4. Verificando associação PFCP..."
PFCP_COUNT=$(docker compose logs $SMF_SERVICE 2>&1 | grep -c "PFCP associated\|PFCP.*association" || echo "0")
if [ "$PFCP_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida ($PFCP_COUNT vez(es))${NC}"
else
    echo -e "${RED}❌ Associação PFCP não encontrada${NC}"
fi
echo ""

# Verificar se há sessão PDU nos logs do SMF
echo "5. Verificando sessão PDU no SMF..."
SESSION_COUNT=$(docker compose logs $SMF_SERVICE 2>&1 | tail -500 | grep -c "PDU.*session\|session.*created\|PDU Session" || echo "0")
if [ "$SESSION_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Sessão PDU encontrada nos logs ($SESSION_COUNT vez(es))${NC}"
else
    echo -e "${YELLOW}⚠️  Nenhuma sessão PDU encontrada nos logs recentes${NC}"
    echo ""
    echo "O UERANSIM não solicita sessão PDU automaticamente após o registro."
    echo "A sessão PDU é estabelecida quando há tráfego de dados."
    echo ""
    echo "Para testar, tente enviar tráfego do UE:"
    echo "  docker compose exec $UE_SERVICE ping -c 3 8.8.8.8"
fi
echo ""

# Testar conectividade
if [ -n "$UE_IP" ]; then
    echo "6. Testando conectividade..."
    if docker compose exec -T $UE_SERVICE ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Conectividade funcionando${NC}"
        
        # Verificar tráfego na ogstun
        sleep 2
        RX_PACKETS=$(docker compose exec -T $UPF_SERVICE cat /sys/class/net/ogstun/statistics/rx_packets 2>/dev/null || echo "0")
        TX_PACKETS=$(docker compose exec -T $UPF_SERVICE cat /sys/class/net/ogstun/statistics/tx_packets 2>/dev/null || echo "0")
        
        if [ "$RX_PACKETS" -gt 0 ] || [ "$TX_PACKETS" -gt 0 ]; then
            echo -e "${GREEN}✅ Tráfego detectado na ogstun (RX: $RX_PACKETS, TX: $TX_PACKETS)${NC}"
        else
            echo -e "${YELLOW}⚠️  Nenhum tráfego detectado na ogstun ainda${NC}"
        fi
    else
        echo -e "${RED}❌ Conectividade não funcionando${NC}"
    fi
fi
echo ""

echo "=========================================="
echo "Resumo"
echo "=========================================="
echo "A sessão PDU no Open5GS/UERANSIM é estabelecida"
echo "automaticamente quando há tráfego de dados."
echo ""
echo "Se o UE tem IP e pode fazer ping, a sessão PDU"
echo "está funcionando, mesmo que não apareça explicitamente"
echo "nos logs como 'PDU Session established'."
echo ""

