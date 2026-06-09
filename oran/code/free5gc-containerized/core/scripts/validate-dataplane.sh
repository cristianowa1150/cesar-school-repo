#!/usr/bin/env bash
#
# Framework de validação do plano de dados (N3/GTP-U, sessões PDU).
# Uso: quando UE (srsUE) estiver ativo.
# Ref: docs/VALIDATION_E2E.md § 1.2

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=============================================="
echo "Validação Data Plane (N3 / GTP-U / PDU)"
echo "=============================================="
echo ""

# --- PFCP (SMF <-> UPF) ---
echo -e "${BLUE}[1] Associação PFCP (SMF <-> UPF)${NC}"
PFCP=$(docker compose logs free5gc-smf 2>&1 | grep -c "PFCP.*Accepted\|Association Setup" 2>/dev/null) || PFCP=0
if [ "${PFCP:-0}" -gt 0 ]; then
  echo -e "  ${GREEN}✓ Associação PFCP detectada${NC}"
else
  echo -e "  ${YELLOW}⚠ Associação PFCP não encontrada nos logs${NC}"
fi
echo ""

# --- Sessões PDU (quando UE ativo) ---
echo -e "${BLUE}[2] Sessões PDU (SMF logs)${NC}"
PDU=$(docker compose logs free5gc-smf 2>&1 | grep -c "PDU.*Session\|Allocate.*IP\|Session Establishment" 2>/dev/null) || PDU=0
if [ "${PDU:-0}" -gt 0 ]; then
  echo -e "  ${GREEN}✓ Indício de sessão(ões) PDU nos logs SMF${NC}"
else
  echo -e "  ${YELLOW}⚠ Nenhuma sessão PDU detectada (normal se UE ainda não conectou)${NC}"
fi
echo ""

# --- GTP-U porta 2152 (N3) ---
echo -e "${BLUE}[3] GTP-U (UDP 2152) — escuta / tráfego${NC}"
if ss -ulnp 2>/dev/null | grep -q 2152; then
  echo -e "  ${GREEN}✓ Alguém em listen na porta 2152${NC}"
else
  echo -e "  ${YELLOW}⚠ Não foi possível confirmar listen em 2152 no host (UPF pode estar no container)${NC}"
fi
echo ""

# --- Subscriber (pré-requisito para UE) ---
echo -e "${BLUE}[4] Subscriber no MongoDB${NC}"
SUPI="imsi-208930000000001"
SUB=$(docker compose exec -T db mongo --quiet --eval "db.getSiblingDB('free5gc').subscriptionData.identityData.countDocuments({ueId: '$SUPI'})" 2>/dev/null | tr -d '\n\r ') || SUB=0
if [ "${SUB:-0}" -gt 0 ]; then
  echo -e "  ${GREEN}✓ Subscriber $SUPI presente${NC}"
else
  echo -e "  ${YELLOW}⚠ Subscriber não encontrado. Execute: ./scripts/add-subscriber.sh${NC}"
fi
echo ""

echo "=============================================="
echo "Para validar fluxo de dados com UE:"
echo "  - Conectar UE (srsUE), obter IP da DNN"
echo "  - ping / iperf3 / traceroute a partir do UE"
echo "  - Captura N3: ./scripts/capture-n3.sh"
echo "=============================================="
