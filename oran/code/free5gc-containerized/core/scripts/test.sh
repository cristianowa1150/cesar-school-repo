#!/bin/bash
#
# Script para testar o sistema free5GC
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
echo "Teste do Sistema free5GC"
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

# Teste 1: Verificar se NRF está acessível
echo "📋 Teste 1: Acessibilidade do NRF"
echo "--------------------------------------------"
if docker compose exec -T free5gc-nrf pgrep -f "nrf" > /dev/null 2>&1; then
    echo -e "${GREEN}✅ NRF está rodando${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ NRF não está rodando${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Teste 2: Verificar se AMF está registrado no NRF
echo "📋 Teste 2: Registro do AMF no NRF"
echo "--------------------------------------------"
AMF_REG=$(docker compose logs free5gc-amf 2>&1 | grep -c "NF registered\|OAuth2 setting receive from NRF" 2>/dev/null | head -1 || echo "0")
AMF_REG=$(echo "$AMF_REG" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
AMF_REG=${AMF_REG:-0}
if [ "$AMF_REG" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ AMF registrado no NRF${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ AMF não registrado no NRF${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Teste 3: Verificar NG Setup (gNB <-> AMF)
echo "📋 Teste 3: NG Setup (gNB <-> AMF)"
echo "--------------------------------------------"
NG_SETUP=$(docker compose logs free5gc-amf 2>&1 | grep -c "NGSetupRequest\|NG-Setup response\|SCTP Accept" 2>/dev/null | head -1 || echo "0")
NG_SETUP=$(echo "$NG_SETUP" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
NG_SETUP=${NG_SETUP:-0}
if [ "$NG_SETUP" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ NG Setup estabelecido ($NG_SETUP ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}❌ NG Setup não estabelecido${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Teste 4: Verificar associação PFCP (SMF <-> UPF)
echo "📋 Teste 4: Associação PFCP (SMF <-> UPF)"
echo "--------------------------------------------"
PFCP=$(docker compose logs free5gc-smf 2>&1 | grep -c "PFCP.*Accepted" 2>/dev/null | head -1 || echo "0")
PFCP=$(echo "$PFCP" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
PFCP=${PFCP:-0}
if [ "$PFCP" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida ($PFCP ocorrência(s))${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠️  Associação PFCP não encontrada (pode ser normal se não houver sessão PDU ativa)${NC}"
fi
echo ""

# Teste 5: Verificar conectividade de rede
echo "📋 Teste 5: Conectividade de Rede"
echo "--------------------------------------------"
# Testar ping entre AMF e RAN (N2)
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

# Teste 6: Verificar logs de erro críticos
echo "📋 Teste 6: Verificação de Erros Críticos"
echo "--------------------------------------------"
ERRORS=0

# Verificar erros no AMF
AMF_ERRORS=$(docker compose logs free5gc-amf 2>&1 | grep -ic "error\|fatal\|panic" 2>/dev/null | head -1 || echo "0")
AMF_ERRORS=$(echo "$AMF_ERRORS" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
AMF_ERRORS=${AMF_ERRORS:-0}
if [ "$AMF_ERRORS" -gt 0 ] 2>/dev/null; then
    echo -e "${YELLOW}⚠️  AMF: $AMF_ERRORS erro(s) encontrado(s)${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ AMF: Nenhum erro crítico${NC}"
fi

# Verificar erros no SMF
SMF_ERRORS=$(docker compose logs free5gc-smf 2>&1 | grep -ic "error\|fatal\|panic" 2>/dev/null | head -1 || echo "0")
SMF_ERRORS=$(echo "$SMF_ERRORS" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
SMF_ERRORS=${SMF_ERRORS:-0}
if [ "$SMF_ERRORS" -gt 0 ] 2>/dev/null; then
    echo -e "${YELLOW}⚠️  SMF: $SMF_ERRORS erro(s) encontrado(s)${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ SMF: Nenhum erro crítico${NC}"
fi

# Verificar erros no UPF
UPF_ERRORS=$(docker compose logs free5gc-upf 2>&1 | grep -ic "error\|fatal\|panic" 2>/dev/null | head -1 || echo "0")
UPF_ERRORS=$(echo "$UPF_ERRORS" | tr -d '\n\r ' | grep -oE '^[0-9]+' || echo "0")
UPF_ERRORS=${UPF_ERRORS:-0}
if [ "$UPF_ERRORS" -gt 0 ] 2>/dev/null; then
    echo -e "${YELLOW}⚠️  UPF: $UPF_ERRORS erro(s) encontrado(s)${NC}"
    ((ERRORS++))
else
    echo -e "${GREEN}✅ UPF: Nenhum erro crítico${NC}"
fi

if [ $ERRORS -eq 0 ]; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi
echo ""

# Resumo
echo "=========================================="
echo "Resumo dos Testes"
echo "=========================================="
echo -e "Testes passados: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Testes falhados: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ TODOS OS TESTES PASSARAM!${NC}"
    exit 0
elif [ $TESTS_FAILED -le 2 ]; then
    echo -e "${YELLOW}⚠️  ALGUNS TESTES FALHARAM${NC}"
    echo "O sistema pode estar funcionando, mas há problemas menores."
    exit 1
else
    echo -e "${RED}❌ MUITOS TESTES FALHARAM${NC}"
    echo "Há problemas significativos no sistema."
    exit 1
fi

