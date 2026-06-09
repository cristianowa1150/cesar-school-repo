#!/bin/bash
#
# Script para verificar o status real do sistema
# Detecta problemas conhecidos e fornece informações detalhadas
#
# Suporta múltiplas RANs (verifica apenas as que estiverem ativas):
#   - UERANSIM split:      ueransim-gnb-containerized / ueransim-ue-containerized
#   - UERANSIM standalone: ueransim (gNB + UE no mesmo container)
#   - srsRAN:              srsran-gnb-containerized / srsran-ue-containerized
#
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-15

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Containers (nomes reais) das NFs usadas para logs
AMF_CONTAINER="open5gs-amf-containerized"
SMF_CONTAINER="open5gs-smf-containerized"

# Candidatos de RAN
GNB_CONTAINERS=(ueransim-gnb-containerized ueransim srsran-gnb-containerized)
UE_CONTAINERS=(ueransim-ue-containerized ueransim srsran-ue-containerized)

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Verificação de Status do Sistema"
echo "Open5GS + RAN (UERANSIM / srsRAN)"
echo "=========================================="
echo ""

# 1. Verificar containers
echo "📋 1. Status dos Containers"
echo "--------------------------------------------"
RAN_ATIVAS=()
for c in "${GNB_CONTAINERS[@]}" "${UE_CONTAINERS[@]}"; do
    if container_running "$c"; then
        case " ${RAN_ATIVAS[*]} " in *" $c "*) ;; *) RAN_ATIVAS+=("$c");; esac
    fi
done
if [ "${#RAN_ATIVAS[@]}" -gt 0 ]; then
    for c in "${RAN_ATIVAS[@]}"; do
        echo -e "${GREEN}✅ RAN: $c rodando${NC}"
    done
else
    echo -e "${RED}❌ Nenhum container de RAN (gNB/UE) em execução${NC}"
fi

if container_running "$AMF_CONTAINER"; then
    echo -e "${GREEN}✅ AMF: Rodando${NC}"
else
    echo -e "${RED}❌ AMF: Não está rodando${NC}"
fi
if container_running "$SMF_CONTAINER"; then
    echo -e "${GREEN}✅ SMF: Rodando${NC}"
else
    echo -e "${RED}❌ SMF: Não está rodando${NC}"
fi
echo ""

# 2. Verificar NG Setup (por gNB ativo)
echo "📡 2. Conexão N2 (gNB <-> AMF)"
echo "--------------------------------------------"
GNB_ATIVOS=0
for gnb in "${GNB_CONTAINERS[@]}"; do
    container_running "$gnb" || continue
    GNB_ATIVOS=1
    NG_SETUP_SUCCESS=$(docker logs "$gnb" 2>&1 | grep -ciE "NG Setup procedure is successful|NG setup procedure (completed|finished)|Connection to AMF.*(established|completed)" || true)
    if [ "${NG_SETUP_SUCCESS:-0}" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅ [$gnb] NG Setup bem-sucedido${NC}"
    else
        echo -e "${RED}❌ [$gnb] NG Setup não encontrado nos logs${NC}"
    fi
done
[ "$GNB_ATIVOS" -eq 0 ] && echo -e "${YELLOW}⚠️  Nenhum gNB em execução${NC}"

AMF_ACCEPTED=$(docker logs "$AMF_CONTAINER" 2>&1 | grep -c "gNB-N2 accepted" || true)
if [ "${AMF_ACCEPTED:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ AMF aceitou conexão de gNB ($AMF_ACCEPTED evento(s))${NC}"
else
    echo -e "${YELLOW}⚠️  AMF não registrou aceitação de gNB${NC}"
fi
echo ""

# 3. Verificar problema de AMF Context (agregado entre gNBs)
echo "🔍 3. Problema de AMF Context"
echo "--------------------------------------------"
AMF_CONTEXT_ERROR=0
for gnb in "${GNB_CONTAINERS[@]}"; do
    container_running "$gnb" || continue
    c=$(docker logs "$gnb" 2>&1 | grep -c "AMF context not found" || true)
    AMF_CONTEXT_ERROR=$((AMF_CONTEXT_ERROR + ${c:-0}))
done
if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}❌ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))${NC}"
    echo "   Possíveis causas: versão do UERANSIM, GUAMI no AMF ou timing do contexto."
else
    echo -e "${GREEN}✅ Nenhum erro de AMF context encontrado${NC}"
fi
echo ""

# 4. Verificar status do(s) UE(s)
echo "📱 4. Status do UE"
echo "--------------------------------------------"
ANY_UE_IP=0
ANY_CELLS=0
UE_ATIVOS=0
for ue in "${UE_CONTAINERS[@]}"; do
    container_running "$ue" || continue
    UE_ATIVOS=1

    UE_IP=$(docker exec "$ue" ip -4 addr show 2>/dev/null | grep -oP 'inet \K10\.60\.[0-9.]+' | head -1 || echo "")
    if [ -n "$UE_IP" ]; then
        echo -e "${GREEN}✅ [$ue] IP de sessão PDU: $UE_IP${NC}"
        ANY_UE_IP=1
    else
        echo -e "${YELLOW}⚠️  [$ue] sem IP de sessão PDU${NC}"
    fi

    UE_CELL_FOUND=$(docker logs "$ue" 2>&1 | grep -ciE "Selected cell|signal detected|camping on|found cell" || true)
    if [ "${UE_CELL_FOUND:-0}" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✅ [$ue] encontrou células ($UE_CELL_FOUND vez(es))${NC}"
        ANY_CELLS=1
    else
        echo -e "${RED}❌ [$ue] não encontrou células${NC}"
    fi

    UE_REG_STATE=$(docker logs "$ue" 2>&1 | grep "UE switches to state" | tail -1 | grep -oP "\[MM-[^\]]+\]" || echo "")
    if [ -n "$UE_REG_STATE" ]; then
        if echo "$UE_REG_STATE" | grep -q "REGISTERED"; then
            echo -e "${GREEN}✅ [$ue] registrado: $UE_REG_STATE${NC}"
        elif echo "$UE_REG_STATE" | grep -q "ATTEMPTING-REGISTRATION"; then
            echo -e "${YELLOW}⚠️  [$ue] tentando registro: $UE_REG_STATE${NC}"
        else
            echo -e "${RED}❌ [$ue] não registrado: $UE_REG_STATE${NC}"
        fi
    fi
done
[ "$UE_ATIVOS" -eq 0 ] && echo -e "${RED}❌ Nenhum UE em execução${NC}"
echo ""

# 5. Verificar sessão PDU / conectividade
echo "🔗 5. Sessão PDU"
echo "--------------------------------------------"
PFCP_ASSOCIATED=$(docker logs "$SMF_CONTAINER" 2>&1 | grep -c "PFCP associated" || true)
if [ "${PFCP_ASSOCIATED:-0}" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✅ Associação PFCP estabelecida ($PFCP_ASSOCIATED UPF(s))${NC}"
else
    echo -e "${YELLOW}⚠️  Associação PFCP não encontrada${NC}"
fi

for ue in "${UE_CONTAINERS[@]}"; do
    container_running "$ue" || continue
    UE_IP=$(docker exec "$ue" ip -4 addr show 2>/dev/null | grep -oP 'inet \K10\.60\.[0-9.]+' | head -1 || echo "")
    [ -z "$UE_IP" ] && continue
    TUN=$(docker exec "$ue" sh -c "ip -o link show 2>/dev/null | sed -E 's/^[0-9]+: ([^:@]+).*/\\1/' | grep -E 'uesimtun|tun_srs' | head -1" 2>/dev/null || echo "")
    if [ -n "$TUN" ]; then
        OK=$(docker exec "$ue" ping -c 1 -W 2 -I "$TUN" 8.8.8.8 >/dev/null 2>&1 && echo 1 || true)
    else
        OK=$(docker exec "$ue" ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && echo 1 || true)
    fi
    if [ "$OK" = "1" ]; then
        echo -e "${GREEN}✅ [$ue] conectividade ativa (ping 8.8.8.8${TUN:+ via $TUN})${NC}"
    else
        echo -e "${YELLOW}⚠️  [$ue] sem conectividade (verifique NAT da DN/UPF)${NC}"
    fi
done
echo ""

# 6. Resumo e recomendações
echo "=========================================="
echo "Resumo e Recomendações"
echo "=========================================="
echo ""

if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠️  PROBLEMA CRÍTICO DETECTADO${NC}"
    echo ""
    echo "O sistema tem o problema de 'AMF context not found'."
    echo "Isso impede o registro de novos UEs, mesmo com NG Setup bem-sucedido."
    echo ""
    echo "Recomendações:"
    echo "1. Verificar a versão do UERANSIM"
    echo "2. Verificar configuração do GUAMI no AMF"
    echo "3. Verificar logs: docker logs <gnb> | grep -i 'AMF\|NG Setup'"
    echo ""
elif [ "$UE_ATIVOS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  Nenhuma RAN/UE ativa para avaliar.${NC}"
    echo "Suba uma RAN (ueransim-ue / ueransim / srsran) e rode novamente."
    echo ""
elif [ "$ANY_UE_IP" -eq 0 ] || [ "$ANY_CELLS" -eq 0 ]; then
    echo -e "${YELLOW}⚠️  PROBLEMAS DETECTADOS${NC}"
    echo ""
    [ "$ANY_UE_IP" -eq 0 ] && echo "- Nenhum UE possui IP de sessão PDU"
    [ "$ANY_CELLS" -eq 0 ] && echo "- Nenhum UE encontrou células"
    echo ""
    echo "Verifique:"
    echo "1. Se o UE está na mesma rede de rádio que o gNB (net-air / ZMQ)"
    echo "2. Se o TAC está correto (deve ser 7)"
    echo "3. Logs do UE: docker logs <ue>"
    echo ""
else
    echo -e "${GREEN}✅ Sistema parece estar funcionando${NC}"
    echo ""
    echo "Pelo menos uma RAN está operacional com UE registrado e IP atribuído."
fi

echo "=========================================="
echo "Fim da Verificação"
echo "=========================================="
