#!/bin/bash
#
# Script para testar comunicação End-to-End (E2E) no free5GC
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-20

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# shellcheck source=lib/ran-docker.sh
. "$SCRIPT_DIR/lib/ran-docker.sh"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Teste End-to-End (E2E) - free5GC"
echo "=========================================="
echo ""

# Verificar se containers estão rodando
if ! docker compose ps | grep -q "Up"; then
    echo -e "${RED}❌ Nenhum container está rodando${NC}"
    echo "Execute: ./scripts/up.sh"
    exit 1
fi

TESTS_PASSED=0
TESTS_FAILED=0

# Verificar se UPF está rodando
echo "📋 Verificando UPF..."
if docker compose ps free5gc-upf | grep -q "Up"; then
    echo -e "${GREEN}✅ UPF está rodando${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ UPF não está rodando${NC}"
    echo "   Tentando reiniciar UPF..."
    docker compose up -d free5gc-upf
    sleep 5
    if docker compose ps free5gc-upf | grep -q "Up"; then
        echo -e "${GREEN}✅ UPF reiniciado com sucesso${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}❌ Falha ao reiniciar UPF${NC}"
        echo "   Verifique logs: docker compose logs free5gc-upf"
        ((TESTS_FAILED++))
    fi
fi
echo ""

# Verificar se subscriber existe
echo "📋 Verificando subscriber no MongoDB..."
SUPI="imsi-208930000000001"
SUBSCRIBER_EXISTS=$(
  docker compose exec -T db mongo --quiet --eval \
  "var d=db.getSiblingDB('free5gc'); print(d.subscriptionData.identityData.countDocuments({ ueId: '$SUPI' }))" \
  2>/dev/null | tr -d '\n\r ' || echo "0"
)
SUBSCRIBER_EXISTS=${SUBSCRIBER_EXISTS:-0}

if [ "$SUBSCRIBER_EXISTS" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Subscriber encontrado (SUPI: $SUPI)${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Subscriber não encontrado${NC}"
    echo "   Execute: ./scripts/add-subscriber.sh"
    read -p "   Deseja adicionar o subscriber agora? (s/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        ./scripts/add-subscriber.sh
        if [ $? -eq 0 ]; then
            ((TESTS_PASSED++))
        else
            ((TESTS_FAILED++))
        fi
    else
        ((TESTS_FAILED++))
    fi
fi
echo ""

# Verificar NG Setup
echo "📋 Verificando NG Setup (gNB <-> AMF)..."
NG_SETUP=$(docker compose logs free5gc-amf 2>&1 | grep -c "NGSetupRequest\|NG-Setup response\|SCTP Accept" 2>/dev/null | head -1 || echo "0")
NG_SETUP=$(echo "$NG_SETUP" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
NG_SETUP=${NG_SETUP:-0}

if [ "$NG_SETUP" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ NG Setup estabelecido ($NG_SETUP ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ NG Setup não estabelecido${NC}"
    echo "   Verifique logs: docker compose logs free5gc-amf | grep NG"
    ((TESTS_FAILED++))
fi
echo ""

# Verificar associação PFCP
echo "📋 Verificando associação PFCP (SMF <-> UPF)..."
PFCP=$(docker compose logs free5gc-smf 2>&1 | grep -c "PFCP.*Accepted" 2>/dev/null | head -1 || echo "0")
PFCP=$(echo "$PFCP" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
PFCP=${PFCP:-0}

if [ "$PFCP" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida ($PFCP ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Associação PFCP não encontrada${NC}"
    echo "   Isso pode ser normal se não houver sessão PDU ativa"
    echo "   Verifique se UPF está rodando: docker compose ps free5gc-upf"
fi
echo ""

# Verificar se há UE conectado (via logs do AMF)
echo "📋 Verificando registro de UE..."
UE_REG=$(docker compose logs free5gc-amf 2>&1 | grep -c "Registration.*Request\|UE.*registered\|InitialUEMessage" 2>/dev/null | head -1 || echo "0")
UE_REG=$(echo "$UE_REG" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
UE_REG=${UE_REG:-0}

if [ "$UE_REG" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Tentativas de registro de UE detectadas ($UE_REG ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Nenhuma tentativa de registro de UE detectada${NC}"
    echo "   Verifique se o UE (srsUE) está configurado corretamente"
fi
echo ""

# Verificar conectividade de rede (srsRAN gNB)
echo "📋 Verificando conectividade de rede..."
AMF_IP=$(docker compose exec -T free5gc-amf ip addr show eth0 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1 || echo "")
if [ -n "$AMF_IP" ] && list_ran_n2_containers; then
    ping_ok=0
    for GNB_IP in $(ran_n2_all_ips); do
        if docker compose exec -T free5gc-amf ping -c 1 -W 1 "$GNB_IP" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ AMF pode alcançar RAN N2 ($GNB_IP)${NC}"
            ping_ok=1
        fi
    done
    [ "$ping_ok" -eq 1 ] && ((TESTS_PASSED++))
    [ "$ping_ok" -eq 0 ] && echo -e "${YELLOW}⚠️  AMF não obteve ping a nenhum RAN N2 (pode ser normal)${NC}"
else
    echo -e "${YELLOW}⚠️  Não foi possível determinar IPs / RAN N2 (AMF=$AMF_IP)${NC}"
fi
echo ""

# Verificar se há sessão PDU ativa (verificar IP do UE)
echo "📋 Verificando sessão PDU..."
# No free5GC, precisamos verificar se há IP atribuído ao UE
# Isso pode ser verificado via logs do SMF ou verificando se há túnel GTP-U ativo

PDU_SESSION=$(docker compose logs free5gc-smf 2>&1 | grep -c "PDU.*Session\|Session.*Created\|Allocate.*IP" 2>/dev/null | head -1 || echo "0")
PDU_SESSION=$(echo "$PDU_SESSION" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
PDU_SESSION=${PDU_SESSION:-0}

if [ "$PDU_SESSION" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Sessão PDU detectada ($PDU_SESSION ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Sessão PDU não detectada${NC}"
    echo "   Isso é normal se o UE ainda não se registrou completamente"
fi
echo ""

# Resumo
echo "=========================================="
echo "Resumo dos Testes E2E"
echo "=========================================="
echo -e "Testes passados: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Testes falhados: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ TODOS OS TESTES PASSARAM!${NC}"
    echo "O sistema está pronto para comunicação E2E."
    echo ""
    echo "📋 Próximos passos:"
    echo "  1. Verifique se o UE está configurado corretamente"
    echo "  2. Inicie o UE (srsUE, se ainda não iniciou)"
    echo "  3. Verifique logs RAN: docker logs srsran-gnb-tradicional | docker logs srsran-cu"
    echo "  4. Teste conectividade do UE após registro"
    exit 0
elif [ $TESTS_FAILED -le 2 ]; then
    echo -e "${YELLOW}⚠️  ALGUNS TESTES FALHARAM${NC}"
    echo "O sistema pode estar funcionando, mas há problemas menores."
    echo ""
    echo "💡 Recomendações:"
    if [ "$SUBSCRIBER_EXISTS" -eq 0 ] 2>/dev/null; then
        echo "  - Execute: ./scripts/add-subscriber.sh"
    fi
    if ! docker compose ps free5gc-upf | grep -q "Up"; then
        echo "  - Verifique logs do UPF: docker compose logs free5gc-upf"
        echo "  - Tente reiniciar: docker compose restart free5gc-upf"
    fi
    exit 1
else
    echo -e "${RED}❌ MUITOS TESTES FALHARAM${NC}"
    echo "Há problemas significativos no sistema."
    echo ""
    echo "💡 Verifique:"
    echo "  - Status dos containers: docker compose ps"
    echo "  - Logs dos serviços: docker compose logs <servico>"
    echo "  - Execute: ./scripts/healthcheck.sh"
    exit 1
fi

