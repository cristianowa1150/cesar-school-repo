#!/bin/bash
# Aplica sysctl (ip_forward) e iptables NAT no host para tráfego UE → internet
# Idempotente: pode ser executado múltiplas vezes
# Requer: cap_net_admin ou root para iptables/sysctl
#
# Uso: ./scripts/apply-nat-host.sh [interface_saida]
# Ex:  ./scripts/apply-nat-host.sh wlo1

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Subrede dos UEs (Open5GS session subnet)
UE_SUBNET="${UE_SUBNET:-10.60.0.0/16}"

# Interface de saída para internet (detecta se não informada)
OUT_IF="${1:-}"

if [[ -z "$OUT_IF" ]]; then
    # Tenta detectar interface com rota default
    OUT_IF=$(ip route show default 2>/dev/null | awk '{print $5}' | head -1)
    if [[ -z "$OUT_IF" ]]; then
        echo "ERRO: Não foi possível detectar interface de saída."
        echo "Uso: $0 <interface>   (ex: wlo1, eth0)"
        exit 1
    fi
    echo "Interface detectada: $OUT_IF"
fi

# Verificar se interface existe
if ! ip link show "$OUT_IF" &>/dev/null; then
    echo "ERRO: Interface '$OUT_IF' não encontrada."
    exit 1
fi

echo "=========================================="
echo "Aplicando NAT no host para subnet UE"
echo "=========================================="
echo "  Subnet UE: $UE_SUBNET"
echo "  Interface saída: $OUT_IF"
echo ""

# 1. IP forwarding
echo "[1/2] Habilitando IP forwarding..."
if sysctl -n net.ipv4.ip_forward 2>/dev/null | grep -q 0; then
    sudo sysctl -w net.ipv4.ip_forward=1
    echo "  net.ipv4.ip_forward = 1"
else
    echo "  Já habilitado."
fi

# 2. Regra NAT (idempotente: verifica antes de adicionar)
echo "[2/2] Regra iptables MASQUERADE..."
if sudo iptables -t nat -C POSTROUTING -s "$UE_SUBNET" -o "$OUT_IF" -j MASQUERADE 2>/dev/null; then
    echo "  Regra já existe."
else
    sudo iptables -t nat -A POSTROUTING -s "$UE_SUBNET" -o "$OUT_IF" -j MASQUERADE
    echo "  Regra adicionada: -s $UE_SUBNET -o $OUT_IF -j MASQUERADE"
fi

echo ""
echo "NAT aplicado. Tráfego de $UE_SUBNET será encaminhado via $OUT_IF."
echo ""
echo "Para persistir após reboot (Ubuntu/Debian):"
echo "  - sysctl: adicione net.ipv4.ip_forward=1 em /etc/sysctl.conf"
echo "  - iptables: use iptables-persistent ou netfilter-persistent"
echo ""
