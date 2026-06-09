#!/usr/bin/env bash
#
# Captura N2/NGAP (SCTP porta 38412). Por padrão usa interface "any" (garante captura
# independente da bridge Docker). Use BRIDGE=br-free5gc para restringir à bridge.
# Ref: docs/VALIDATION_E2E.md § 3.1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CAPTURES_DIR="${CAPTURES_DIR:-$PROJECT_DIR/captures}"
# Padrão: "any" garante captura independente da bridge Docker. BRIDGE=br-free5gc restringe à bridge.
IFACE="${BRIDGE:-any}"

mkdir -p "$CAPTURES_DIR"
FILE="$CAPTURES_DIR/n2_$(date +%Y%m%d_%H%M%S).pcap"

echo "Captura N2 (SCTP port 38412) na interface $IFACE"
echo "Arquivo: $FILE"
echo ""
echo "Fluxo: 1) Deixe rodando  2) docker restart srsran-gnb-tradicional  3) Aguarde 10–15 s  4) Ctrl+C"
echo ""

sudo tcpdump -i "$IFACE" -w "$FILE" -s 0 'sctp and port 38412'
