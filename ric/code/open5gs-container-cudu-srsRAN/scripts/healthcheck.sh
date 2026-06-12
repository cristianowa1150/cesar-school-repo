#!/bin/bash
# Script para verificar a saúde dos serviços Open5GS
# Detecta problemas conhecidos e fornece informações relevantes
# Uso: ./scripts/healthcheck.sh
#
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-15

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Cores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ----------------------------------------------------------------------------
# Detecção de RANs (suporta 3 opções; só verifica as que estiverem ativas):
#   - UERANSIM split:      ueransim-gnb-containerized / ueransim-ue-containerized
#   - UERANSIM standalone: ueransim (gNB + UE no mesmo container)
#   - srsRAN split-8:      srsran-cu-du / srsran-ue
#   - srsRAN strict CU/DU: srsran-cu / srsran-du / srsran-ue
# ----------------------------------------------------------------------------
GNB_CONTAINERS=(ueransim-gnb-containerized ueransim srsran-cu-du-containerized srsran-du-containerized srsran-cu-containerized)
UE_CONTAINERS=(ueransim-ue-containerized ueransim srsran-ue-containerized)

container_running() {
    docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$1"
}

gnb_n2_ip() {
    case "$1" in
        srsran-cu-du-containerized) echo "10.20.0.101" ;;
        srsran-cu-containerized) echo "10.20.0.110" ;;
        ueransim-gnb-containerized|ueransim) echo "10.20.0.100" ;;
        *) return 1 ;;
    esac
}

ue_has_radio_or_session() {
    ue="$1"
    if docker exec "$ue" ip -4 addr show 2>/dev/null | grep -q 'inet 10\.60\.'; then
        return 0
    fi
    docker logs "$ue" 2>&1 | grep -qiE "Selected cell|signal detected|camping on|found cell|Random Access Complete|RRC Connected|PDU Session Establishment successful"
}

echo "=========================================="
echo "Healthcheck - Laboratório Open5GS"
echo "=========================================="
echo ""

# Verificar status dos containers
echo "Status dos containers:"
docker compose ps
echo ""

# Verificar processos dos serviços
echo "Verificando processos dos serviços..."
declare -A SERVICE_CONTAINERS=(
    ["nrf"]="open5gs-nrf-containerized"
    ["scp"]="open5gs-scp-containerized"
    ["amf"]="open5gs-amf-containerized"
    ["smf"]="open5gs-smf-containerized"
    ["ausf"]="open5gs-ausf-containerized"
    ["udm"]="open5gs-udm-containerized"
    ["udr"]="open5gs-udr-containerized"
    ["pcf"]="open5gs-pcf-containerized"
    ["nssf"]="open5gs-nssf-containerized"
    ["upf-a"]="open5gs-upf-containerized-a"
    ["upf-b"]="open5gs-upf-containerized-b"
)

for service in "${!SERVICE_CONTAINERS[@]}"; do
    container="${SERVICE_CONTAINERS[$service]}"
    if docker exec "$container" pgrep -f "open5gs-" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ ${service} está rodando${NC}"
    else
        echo -e "${RED}✗ ${service} não está rodando${NC}"
    fi
done
echo ""

# Verificar conectividade NRF
echo "Verificando NRF..."
# NRF usa HTTP/2 puro (nghttp2) que não é facilmente testável com curl simples
# Verificamos se o processo está rodando e se a porta está escutando
if docker exec open5gs-nrf-containerized pgrep -f "open5gs-nrfd" > /dev/null 2>&1; then
    if docker exec open5gs-nrf-containerized netstat -tlnp 2>/dev/null | grep -q ":7777" || \
       docker exec open5gs-nrf-containerized ss -tlnp 2>/dev/null | grep -q ":7777"; then
        echo -e "${GREEN}✓ NRF está rodando e escutando na porta 7777${NC}"
    else
        echo -e "${YELLOW}⚠ NRF está rodando mas porta 7777 não está escutando${NC}"
    fi
else
    echo -e "${RED}✗ NRF não está rodando${NC}"
fi
echo ""

# Verificar se NFs estão registradas no NRF
echo "Verificando registro de NFs no NRF..."
# Nota: O endpoint HTTP/2 do NRF requer cliente HTTP/2 nativo (nghttp2)
# Como alternativa, verificamos se as NFs estão rodando e se o NRF está healthy
# O registro real é verificado pelos logs e pelo fato de as NFs estarem funcionando
if docker compose ps nrf | grep -q "healthy"; then
    echo "✓ NRF está healthy (NFs devem estar registradas)"
    echo "  (Para verificar registro detalhado, consulte os logs: docker compose logs nrf | grep 'NF registered')"
else
    echo "⚠ NRF não está healthy ainda"
fi
echo ""

# Verificar conectividade entre serviços
echo "Verificando conectividade de rede..."
echo "Testando N2 (AMF <-> gNB):"
N2_ATIVOS=0
for gnb in ueransim-gnb-containerized ueransim srsran-cu-du-containerized srsran-cu-containerized; do
    container_running "$gnb" || continue
    n2_ip="$(gnb_n2_ip "$gnb" || true)"
    [ -n "$n2_ip" ] || continue
    N2_ATIVOS=1
    if docker exec open5gs-amf-containerized ping -c 1 -W 2 "$n2_ip" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ AMF alcança [$gnb] em N2 ($n2_ip)${NC}"
    else
        echo -e "${YELLOW}⚠ AMF não respondeu ping para [$gnb] em N2 ($n2_ip); verificando NG Setup nos logs${NC}"
    fi
done
if [ "$N2_ATIVOS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Nenhum container com N2 em execução${NC}"
fi

echo "Testando N3 (gNB <-> UPFs):"
GNB_ATIVOS=0
for gnb in ueransim-gnb-containerized ueransim srsran-cu-du-containerized srsran-cu-containerized; do
    container_running "$gnb" || continue
    GNB_ATIVOS=1
    if ! docker exec "$gnb" sh -c 'command -v ping >/dev/null 2>&1'; then
        echo -e "${YELLOW}⚠ [$gnb] sem utilitário 'ping'; teste N3 ignorado${NC}"
        continue
    fi
    for upf in "UPF-A 10.30.0.21" "UPF-B 10.30.0.22"; do
        name="${upf%% *}"; uip="${upf##* }"
        if docker exec "$gnb" ping -c 1 -W 2 "$uip" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ [$gnb] alcança $name ($uip)${NC}"
        else
            echo -e "${RED}✗ [$gnb] NÃO alcança $name ($uip)${NC}"
        fi
    done
done
if [ "$GNB_ATIVOS" -eq 0 ]; then
    echo -e "${YELLOW}⚠ Nenhum container com N3 em execução (ueransim-gnb / ueransim / srsran-cu-du / srsran-cu)${NC}"
fi

echo "Testando N4 (SMF <-> UPF-A):"
if docker exec open5gs-smf-containerized ping -c 1 10.40.0.21 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SMF pode alcançar UPF-A${NC}"
else
    echo -e "${RED}✗ SMF não pode alcançar UPF-A${NC}"
fi

echo "Testando N4 (SMF <-> UPF-B):"
if docker exec open5gs-smf-containerized ping -c 1 10.40.0.22 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ SMF pode alcançar UPF-B${NC}"
else
    echo -e "${RED}✗ SMF não pode alcançar UPF-B${NC}"
fi

echo "Testando N6 (UPF-A <-> DN):"
if docker exec open5gs-upf-containerized-a ping -c 1 10.50.0.100 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ UPF-A pode alcançar DN${NC}"
else
    echo -e "${RED}✗ UPF-A não pode alcançar DN${NC}"
fi

echo "Testando N6 (UPF-B <-> DN):"
if docker exec open5gs-upf-containerized-b ping -c 1 10.50.0.100 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ UPF-B pode alcançar DN${NC}"
else
    echo -e "${RED}✗ UPF-B não pode alcançar DN${NC}"
fi
echo ""

# Verificar NG Setup (por gNB ativo)
echo "Verificando NG Setup (gNB <-> AMF)..."
for gnb in "${GNB_CONTAINERS[@]}"; do
    container_running "$gnb" || continue
    NG_OK=$(docker logs "$gnb" 2>&1 | grep -ciE "NG Setup procedure is successful|NG setup procedure (completed|finished)|Connection to AMF.*(established|completed)" || true)
    if [ "${NG_OK:-0}" -gt 0 ] 2>/dev/null; then
        echo -e "${GREEN}✓ [$gnb] NG Setup OK${NC}"
    else
        echo -e "${YELLOW}⚠ [$gnb] NG Setup não encontrado nos logs${NC}"
    fi
done

# Verificar problema de AMF Context (agregado entre gNBs UERANSIM)
AMF_CONTEXT_ERROR=0
for gnb in "${GNB_CONTAINERS[@]}"; do
    container_running "$gnb" || continue
    c=$(docker logs "$gnb" 2>&1 | grep -c "AMF context not found" || true)
    AMF_CONTEXT_ERROR=$((AMF_CONTEXT_ERROR + ${c:-0}))
done
if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo -e "${RED}⚠ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))${NC}"
    echo "   Execute: ./scripts/test-system-status.sh para mais detalhes"
else
    echo -e "${GREEN}✓ Nenhum erro de AMF context encontrado${NC}"
fi
echo ""

# Verificar associação PFCP
echo "Verificando associação PFCP (SMF <-> UPF)..."
PFCP_ASSOCIATED=$(docker compose logs smf 2>&1 | grep -c "PFCP associated" 2>/dev/null | head -1 || echo "0")
if [ "$PFCP_ASSOCIATED" -gt 0 ] 2>/dev/null; then
    echo -e "${GREEN}✓ Associação PFCP estabelecida ($PFCP_ASSOCIATED UPF(s))${NC}"
else
    echo -e "${YELLOW}⚠ Associação PFCP não encontrada${NC}"
fi
echo ""

# Verificar se o(s) UE(s) estão conectados (por UE ativo)
echo "Verificando status do UE..."
UE_ATIVOS=0
for ue in "${UE_CONTAINERS[@]}"; do
    container_running "$ue" || continue
    UE_ATIVOS=1
    if ! docker exec "$ue" sh -c 'pgrep -f "nr-ue|srsue" >/dev/null 2>&1'; then
        echo -e "${RED}✗ [$ue] processo de UE (nr-ue/srsue) não encontrado${NC}"
        continue
    fi
    echo -e "${GREEN}✓ [$ue] UE está rodando${NC}"

    # IP da sessão PDU (uesimtun0 do UERANSIM ou tun do srsUE; pool 10.60.0.0/16)
    UE_IP=$(docker exec "$ue" ip -4 addr show 2>/dev/null | grep -oP 'inet \K10\.60\.[0-9.]+' | head -1 || echo "")
    if [ -n "$UE_IP" ]; then
        echo -e "${GREEN}  ✓ [$ue] IP de sessão PDU: $UE_IP${NC}"
        # Descobre a interface de túnel (uesimtun0 / tun_srsue) para testar pelo caminho 5G
        TUN=$(docker exec "$ue" sh -c "ip -o link show 2>/dev/null | sed -E 's/^[0-9]+: ([^:@]+).*/\\1/' | grep -E 'uesimtun|tun_srs' | head -1" 2>/dev/null || echo "")
        if [ -n "$TUN" ]; then
            PING_OK=$(docker exec "$ue" ping -c 1 -W 2 -I "$TUN" 8.8.8.8 >/dev/null 2>&1 && echo 1 || echo 0)
        else
            PING_OK=$(docker exec "$ue" ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1 && echo 1 || echo 0)
        fi
        if [ "$PING_OK" = "1" ]; then
            echo -e "${GREEN}  ✓ [$ue] conectividade ativa (ping 8.8.8.8${TUN:+ via $TUN})${NC}"
        else
            echo -e "${YELLOW}  ⚠ [$ue] sem conectividade (verifique NAT da DN/UPF)${NC}"
        fi
    else
        echo -e "${YELLOW}  ⚠ [$ue] sem IP de sessão PDU${NC}"
    fi

    # srsUE 4G/NR nem sempre imprime "Selected cell"; PDU/TUN ou RRC comprovam radio funcional.
    if ue_has_radio_or_session "$ue"; then
        echo -e "${GREEN}  ✓ [$ue] radio/celula OK (RRC/PDU detectado)${NC}"
    else
        echo -e "${YELLOW}  ⚠ [$ue] sem evidencia de celula/RRC nos logs atuais${NC}"
    fi
done
if [ "$UE_ATIVOS" -eq 0 ]; then
    echo -e "${RED}✗ Nenhum container de UE em execução (ueransim-ue / ueransim / srsran-ue)${NC}"
fi

echo ""
echo "=========================================="
echo "Healthcheck concluído"
echo "=========================================="
echo ""
echo "💡 Dicas:"
echo "  - Para verificação detalhada: ./scripts/test-system-status.sh"
echo "  - Para teste de conectividade: ./scripts/test_ue_connection.sh"
echo "  - Para teste de failover: ./scripts/test_upf_failover.sh"
echo ""
