#!/usr/bin/env bash
#
# Checklist de validação final E2E (ref. docs/VALIDATION_E2E.md § 4).
# Executa validate-n2-ngap e resume itens do checklist.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"
# shellcheck source=lib/ran-docker.sh
. "$SCRIPT_DIR/lib/ran-docker.sh"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=============================================="
echo "Checklist Validação E2E — Lab 5G SA"
echo "=============================================="
echo ""

FAIL=0

# 1. SCTP / N2 established (host ou evidência por logs)
echo -n "[ ] N2/SCTP established "
SCTP_OK=0
if ss -tnp state established '( dport = :38412 or sport = :38412 )' 2>/dev/null | grep -q sctp || \
   sudo ss -tnp state established '( dport = :38412 or sport = :38412 )' 2>/dev/null | grep -q sctp; then
  SCTP_OK=1
fi
if [ "$SCTP_OK" -eq 0 ]; then
  NG_AMF=$(docker compose logs free5gc-amf 2>&1 | grep -c "NGSetupRequest\|NG-Setup response\|NGSetupResponse" 2>/dev/null) || NG_AMF=0
  _rl="$(ran_n2_logs 2>/dev/null || true)"
  GNB_RX=$(echo "$_rl" | grep -c "Rx PDU: NGSetupResponse" 2>/dev/null) || GNB_RX=0
  GNB_TX=$(echo "$_rl" | grep -c "Tx PDU: NGSetupRequest" 2>/dev/null) || GNB_TX=0
  [ "${NG_AMF:-0}" -gt 0 ] && ( [ "${GNB_RX:-0}" -gt 0 ] || [ "${GNB_TX:-0}" -gt 0 ] ) && SCTP_OK=1
fi
if [ "$SCTP_OK" -eq 1 ]; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FALHA${NC}"
  FAIL=$((FAIL+1))
fi

# 2. NG Setup aceito (AMF + gNB)
echo -n "[ ] NG Setup aceito "
NG=$(docker compose logs free5gc-amf 2>&1 | grep -c "NGSetupRequest\|NG-Setup response\|NGSetupResponse" 2>/dev/null) || NG=0
_rl="$(ran_n2_logs 2>/dev/null || true)"
GNB_RX=$(echo "$_rl" | grep -c "Rx PDU: NGSetupResponse" 2>/dev/null) || GNB_RX=0
GNB_TX=$(echo "$_rl" | grep -c "Tx PDU: NGSetupRequest" 2>/dev/null) || GNB_TX=0
if [ "${NG:-0}" -gt 0 ] && ( [ "${GNB_RX:-0}" -gt 0 ] || [ "${GNB_TX:-0}" -gt 0 ] ); then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${RED}FALHA${NC}"
  FAIL=$((FAIL+1))
fi

# 3. AMF registra gNB (evidência nos logs)
echo -n "[ ] AMF registra gNB "
if docker compose logs free5gc-amf 2>&1 | grep -q "Number of gNBs is now\|Added.*gNB\|NGSetupRequest\|NG-Setup response"; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}? (verificar logs AMF)${NC}"
fi

# 4. Logs RAN (N2) consistentes (sem falha) — por container
echo -n "[ ] Logs RAN (N2) consistentes (sem falha) "
_chk4_ok=1
if list_ran_n2_containers; then
  for c in "${RAN_N2_CONTAINERS[@]}"; do
    _cl=$(docker logs "$c" 2>&1 || true)
    if echo "$_cl" | grep -q "Failed to connect to AMF\|Network is unreachable"; then
      _chk4_ok=0
    elif ! echo "$_cl" | grep -q "Rx PDU: NGSetupResponse\|CU-CP started successfully\|CU started"; then
      _chk4_ok=0
    fi
  done
fi
if list_ran_n2_containers && [ "$_chk4_ok" -eq 1 ]; then
  echo -e "${GREEN}OK${NC}"
elif ! list_ran_n2_containers; then
  echo -e "${YELLOW}sem RAN${NC}"
else
  echo -e "${RED}FALHA${NC}"
  FAIL=$((FAIL+1))
fi

# 5. Restart count RAN (N2)
echo -n "[ ] Containers RAN (N2) estáveis (RestartCount) "
if list_ran_n2_containers; then
  _rc_ok=1
  for c in "${RAN_N2_CONTAINERS[@]}"; do
    RC=$(docker inspect --format '{{.RestartCount}}' "$c" 2>/dev/null || echo "?")
    [ "${RC:-0}" -gt 2 ] 2>/dev/null && _rc_ok=0
  done
  if [ "$_rc_ok" -eq 1 ]; then
    echo -e "${GREEN}OK (${#RAN_N2_CONTAINERS[@]} container(s))${NC}"
  else
    echo -e "${YELLOW}algum RestartCount alto${NC}"
  fi
else
  echo -e "${YELLOW}container não encontrado${NC}"
fi

# 6. Ambiente pronto para UE (subscriber)
echo -n "[ ] Ambiente pronto para UE (subscriber) "
SUB=$(docker compose exec -T db mongo --quiet --eval "db.getSiblingDB('free5gc').subscriptionData.identityData.countDocuments({})" 2>/dev/null | tr -d '\n\r ') || SUB=0
if [ "${SUB:-0}" -gt 0 ]; then
  echo -e "${GREEN}OK${NC}"
else
  echo -e "${YELLOW}adicionar subscriber${NC}"
fi

echo ""
if [ "$FAIL" -eq 0 ]; then
  echo -e "${GREEN}Checklist: critérios críticos atendidos.${NC}"
  echo "Capturas: ./scripts/capture-n2.sh e ./scripts/capture-n3.sh"
  exit 0
else
  echo -e "${RED}Checklist: $FAIL item(ns) falharam. Execute ./scripts/validate-n2-ngap.sh${NC}"
  exit 1
fi
