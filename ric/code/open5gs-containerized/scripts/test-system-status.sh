#!/bin/bash
#
# Script para verificar o status real do sistema

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

RAN_CONTAINER="ueransim"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

is_running() {
    docker inspect -f '{{.State.Status}}' "$1" 2>/dev/null | grep -q "running"
}

echo "=========================================="
echo "Verificação de Status do Sistema"
echo "Open5GS Containerized"
echo "=========================================="
echo ""

echo "📋 1. Status dos Containers"
echo "--------------------------------------------"
if is_running "$RAN_CONTAINER"; then
    echo -e "${GREEN}✅ RAN (gNB+UE): Rodando${NC}"
else
    echo -e "${RED}❌ RAN (gNB+UE): Não está rodando${NC}"
fi

for svc in amf smf upf-a upf-b mongodb nrf; do
    if docker compose ps "$svc" 2>/dev/null | grep -q "Up"; then
        echo -e "${GREEN}✅ ${svc}: Rodando${NC}"
    else
        echo -e "${RED}❌ ${svc}: Não está rodando${NC}"
    fi
done
echo ""

echo "📡 2. Conexão N2 (gNB <-> AMF)"
echo "--------------------------------------------"
if is_running "$RAN_CONTAINER"; then
    NG_SETUP_SUCCESS=$(docker logs "$RAN_CONTAINER" 2>&1 | grep -c "NG Setup procedure is successful" 2>/dev/null | head -1 || echo "0")
    if [ "$NG_SETUP_SUCCESS" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅ NG Setup bem-sucedido ($NG_SETUP_SUCCESS vez(es))${NC}"
    else
        echo -e "${RED}❌ NG Setup não encontrado nos logs${NC}"
    fi
else
    NG_SETUP_SUCCESS=0
    echo -e "${RED}❌ Container RAN não está rodando${NC}"
fi

AMF_ACCEPTED=$(docker compose logs amf 2>&1 | grep -c "gNB-N2 accepted" 2>/dev/null | head -1 || echo "0")
if [ "$AMF_ACCEPTED" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ AMF aceitou conexão do gNB ($AMF_ACCEPTED vez(es))${NC}"
else
    echo -e "${YELLOW}⚠️  AMF não aceitou conexão do gNB${NC}"
fi
echo ""

echo "🔍 3. Problema de AMF Context"
echo "--------------------------------------------"
if is_running "$RAN_CONTAINER"; then
    AMF_CONTEXT_ERROR=$(docker logs "$RAN_CONTAINER" 2>&1 | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
else
    AMF_CONTEXT_ERROR=0
fi
if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))${NC}"
else
    echo -e "${GREEN}✅ Nenhum erro de AMF context encontrado${NC}"
fi
echo ""

echo "📱 4. Status do UE"
echo "--------------------------------------------"
if is_running "$RAN_CONTAINER"; then
    UE_IP=$(docker exec "$RAN_CONTAINER" ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
    UE_CELL_FOUND=$(docker logs "$RAN_CONTAINER" 2>&1 | grep -c "Selected cell\|signal detected" 2>/dev/null | head -1 || echo "0")
    UE_REG_STATE=$(docker logs "$RAN_CONTAINER" 2>&1 | grep "UE switches to state" | tail -1 | grep -oP "\[MM-[^\]]+\]" || echo "")
else
    UE_IP=""
    UE_CELL_FOUND=0
    UE_REG_STATE=""
fi

if [ -n "$UE_IP" ]; then
    echo -e "${GREEN}✅ UE possui IP: $UE_IP${NC}"
else
    echo -e "${YELLOW}⚠️  UE não possui IP atribuído${NC}"
fi

if [ "$UE_CELL_FOUND" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ UE encontrou células ($UE_CELL_FOUND vez(es))${NC}"
else
    echo -e "${RED}❌ UE não encontrou células${NC}"
fi

if [ -n "$UE_REG_STATE" ]; then
    if echo "$UE_REG_STATE" | grep -q "REGISTERED"; then
        echo -e "${GREEN}✅ UE está registrado: $UE_REG_STATE${NC}"
    else
        echo -e "${YELLOW}⚠️  Estado do UE: $UE_REG_STATE${NC}"
    fi
fi
echo ""

echo "🔗 5. Sessão PDU"
echo "--------------------------------------------"
PFCP_ASSOCIATED=$(docker compose logs smf 2>&1 | grep -c "PFCP associated" 2>/dev/null | head -1 || echo "0")
if [ "$PFCP_ASSOCIATED" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida ($PFCP_ASSOCIATED UPF(s))${NC}"
else
    echo -e "${YELLOW}⚠️  Associação PFCP não encontrada${NC}"
fi

if [ -n "$UE_IP" ] && is_running "$RAN_CONTAINER"; then
    if docker exec "$RAN_CONTAINER" ping -c 1 -W 1 8.8.8.8 > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Conectividade ativa (ping para 8.8.8.8 OK)${NC}"
    else
        echo -e "${YELLOW}⚠️  Sem conectividade (ping falhou)${NC}"
    fi
fi
echo ""

echo "=========================================="
echo "Resumo e Recomendações"
echo "=========================================="
echo ""

if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠️  PROBLEMA CRÍTICO DETECTADO${NC}"
    echo "Use UERANSIM 3.2.6 (configurado no projeto) e reinicie: docker restart ueransim"
elif [ -z "$UE_IP" ] || [ "$UE_CELL_FOUND" -eq 0 ] 2>/dev/null; then
    echo -e "${YELLOW}⚠️  PROBLEMAS DETECTADOS${NC}"
    echo "Verifique: ./scripts/add-subscriber.sh && ./scripts/up_ran.sh"
    echo "Logs: docker logs ueransim"
else
    echo -e "${GREEN}✅ Sistema parece estar funcionando${NC}"
fi

echo "=========================================="
echo "Fim da Verificação"
echo "=========================================="
