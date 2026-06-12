#!/bin/bash
# Troubleshooting: tcpdump, ip route, iptables counters
# Uso: ./scripts/troubleshoot.sh [comando]
# Comandos: routes | iptables | capture-n2 | capture-n3 | capture-ue | all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

UE_CONTAINER="${UE_CONTAINER:-ueransim-containerized}"
GNB_CONTAINER="${GNB_CONTAINER:-ueransim-containerized}"
AMF_IP="10.20.0.11"
UPF_IP="10.30.0.21"
UE_SUBNET="10.60.0.0/16"

cmd="${1:-all}"

echo "=========================================="
echo "5G SA Troubleshooting"
echo "=========================================="
echo ""

case "$cmd" in
    routes)
        echo "=== Rotas no UE (container $UE_CONTAINER) ==="
        docker exec "$UE_CONTAINER" ip route show 2>/dev/null || echo "Container não encontrado ou sem ip route"
        echo ""
        echo "=== Interfaces no UE ==="
        docker exec "$UE_CONTAINER" ip addr show 2>/dev/null | grep -E "inet |uesimtun|tun_" || true
        ;;
    iptables)
        echo "=== Contadores iptables NAT (host) ==="
        sudo iptables -t nat -L POSTROUTING -v -n 2>/dev/null | head -20
        echo ""
        echo "=== Regras FILTER FORWARD ==="
        sudo iptables -L FORWARD -v -n 2>/dev/null | head -15
        ;;
    capture-n2)
        echo "=== Captura N2 (NGAP/SCTP) - AMF $AMF_IP:38412 ==="
        echo "Executando tcpdump por 15s... (Ctrl+C para parar antes)"
        sudo timeout 15 tcpdump -i any -n "host $AMF_IP and port 38412" 2>/dev/null || tcpdump -i any -n "host $AMF_IP and port 38412"
        ;;
    capture-n3)
        echo "=== Captura N3 (GTP-U) - UPF $UPF_IP:2152 ==="
        echo "Executando tcpdump por 15s..."
        sudo timeout 15 tcpdump -i any -n "host $UPF_IP and port 2152" 2>/dev/null || tcpdump -i any -n "host $UPF_IP and port 2152"
        ;;
    capture-ue)
        echo "=== Captura tráfego UE (TUN) ==="
        TUN=$(docker exec "$UE_CONTAINER" ip link show 2>/dev/null | grep -oP 'uesimtun\d*|tun_\w+' | head -1)
        if [[ -n "$TUN" ]]; then
            echo "Interface TUN: $TUN"
            docker exec "$UE_CONTAINER" timeout 10 tcpdump -i "$TUN" -n 2>/dev/null || true
        else
            echo "Tentando captura em qualquer interface do container..."
            docker exec "$UE_CONTAINER" timeout 10 tcpdump -i any -n 2>/dev/null || echo "tcpdump não disponível no container"
        fi
        ;;
    all)
        "$0" routes
        echo ""
        "$0" iptables
        echo ""
        echo "=== Logs AMF (últimas 5 linhas) ==="
        docker compose logs amf --tail 5 2>/dev/null || true
        echo ""
        echo "=== Logs gNB/UE (últimas 10 linhas) ==="
        docker compose logs ueransim --tail 10 2>/dev/null || true
        ;;
    *)
        echo "Uso: $0 [routes|iptables|capture-n2|capture-n3|capture-ue|all]"
        echo ""
        echo "  routes      - Rotas e interfaces no container UE"
        echo "  iptables    - Contadores NAT e FORWARD no host"
        echo "  capture-n2   - tcpdump N2 (NGAP SCTP)"
        echo "  capture-n3   - tcpdump N3 (GTP-U)"
        echo "  capture-ue   - tcpdump na interface TUN do UE"
        echo "  all         - Executa routes, iptables e mostra logs"
        exit 1
        ;;
esac
