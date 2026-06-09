#!/usr/bin/env bash
#
# Captura N3 (GTP-U UDP 2152) na bridge Docker.
# Uso: executar no host (requer permissão para tcpdump na interface da bridge).
# Ref: docs/VALIDATION_E2E.md § 3.2

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPTURES_DIR="${CAPTURES_DIR:-$PROJECT_DIR/captures}"
# Padrão: "any" garante captura. BRIDGE=br-free5gc restringe à bridge.
IFACE="${BRIDGE:-any}"

mkdir -p "$CAPTURES_DIR"
FILE="$CAPTURES_DIR/n3_$(date +%Y%m%d_%H%M%S).pcap"

echo "Captura N3 (GTP-U UDP 2152) na interface $IFACE"
echo "Arquivo: $FILE"
echo ""
echo "Fluxo sugerido: com UE conectado e sessão PDU ativa, inicie a captura e execute ping do UE."
echo "Parar com Ctrl+C."
echo ""

sudo tcpdump -i "$IFACE" -w "$FILE" -s 0 'udp port 2152'
