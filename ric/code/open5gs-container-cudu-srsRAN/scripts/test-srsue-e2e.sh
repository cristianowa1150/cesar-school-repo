#!/bin/bash
# Teste end-to-end do srsUE pela RAN desagregada CU/DU.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

UE_CONTAINER="srsran-ue-containerized"
TEST_HOST="${TEST_HOST:-8.8.8.8}"
SRSRAN_PROFILE="${SRSRAN_PROFILE:-e2e}"

echo "=========================================="
echo "Teste E2E - srsUE via srsRAN CU/DU"
echo "=========================================="
echo ""

if ! docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER"; then
    echo "ERRO: $UE_CONTAINER nao esta rodando."
    echo "Execute: ./scripts/up_ran.sh"
    exit 1
fi

echo "Verificando interface tun_srsue..."
for _ in $(seq 1 "${TUN_WAIT_RETRIES:-45}"); do
    if docker exec "$UE_CONTAINER" ip -4 addr show tun_srsue 2>/dev/null | grep -q "inet "; then
        break
    fi
    sleep 2
done

if ! docker exec "$UE_CONTAINER" ip link show tun_srsue > /dev/null 2>&1; then
    echo "ERRO: tun_srsue nao existe no srsUE."
    echo "Logs recentes:"
    docker compose --profile "$SRSRAN_PROFILE" logs --tail 80 srsran-ue || true
    exit 1
fi

UE_IP="$(docker exec "$UE_CONTAINER" ip -4 addr show tun_srsue | grep -oP 'inet \K[0-9.]+' | head -1 || true)"
if [ -z "$UE_IP" ]; then
    echo "ERRO: tun_srsue existe, mas ainda nao recebeu IP."
    docker compose --profile "$SRSRAN_PROFILE" logs --tail 80 srsran-ue || true
    exit 1
fi

echo "IP do srsUE: $UE_IP"
echo ""

echo "Verificando sessao PDU nos logs..."
if docker compose --profile "$SRSRAN_PROFILE" logs srsran-ue 2>&1 | grep -q "PDU Session Establishment successful"; then
    echo "Sessao PDU estabelecida."
else
    echo "Aviso: nao encontrei confirmacao de sessao PDU nos logs recentes."
fi

echo ""
echo "Testando ping via tun_srsue para $TEST_HOST..."
docker exec "$UE_CONTAINER" ping -c 4 -W 3 -I tun_srsue "$TEST_HOST"

echo ""
echo "=========================================="
echo "Teste E2E concluido com sucesso"
echo "=========================================="
