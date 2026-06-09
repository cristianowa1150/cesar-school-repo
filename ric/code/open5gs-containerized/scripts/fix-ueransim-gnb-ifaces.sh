#!/usr/bin/env bash
set -euo pipefail

# Container único do UERANSIM (gNB + UE)
GNB_CTN="ueransim"

# Prefixos das redes (devem bater com docker-compose.yml)
N2_PFX="10.20.0."
N3_PFX="10.30.0."

echo "[INFO] Aguardando interfaces subirem no container..."
# Aguarda o container estar "up"
for i in {1..30}; do
  if docker ps --format '{{.Names}}' | grep -q "^${GNB_CTN}$"; then
    break
  fi
  sleep 1
done

# Aguarda IPs aparecerem
for i in {1..30}; do
  IPS="$(docker exec "$GNB_CTN" sh -lc "ip -o -4 addr show | awk '{print \$2, \$4}'" || true)"
  echo "$IPS" | grep -q "$N2_PFX" && echo "$IPS" | grep -q "$N3_PFX" && break
  sleep 1
done

N2_IP="$(docker exec "$GNB_CTN" sh -lc "ip -o -4 addr show | awk -v pfx='$N2_PFX' '\$4 ~ \"^\"pfx {sub(/\\/.*$/, \"\", \$4); print \$4; exit}'" 2>/dev/null || true)"
N3_IP="$(docker exec "$GNB_CTN" sh -lc "ip -o -4 addr show | awk -v pfx='$N3_PFX' '\$4 ~ \"^\"pfx {sub(/\\/.*$/, \"\", \$4); print \$4; exit}'" 2>/dev/null || true)"

if [ -z "$N2_IP" ] || [ -z "$N3_IP" ]; then
  echo "[FATAL] Nao foi possivel identificar IPs de N2/N3."
  docker exec "$GNB_CTN" sh -lc "ip -br a" || true
  exit 1
fi

echo "[INFO] Detectado:"
echo "  N2_BIND_IP=$N2_IP (prefixo $N2_PFX)"
echo "  N3_BIND_IP=$N3_IP (prefixo $N3_PFX)"

# Atualiza variáveis de ambiente do serviço via override (sem editar o compose principal)
mkdir -p ./overrides

cat > ./overrides/ueransim-ifaces.override.yml <<EOF
services:
  ueransim:
    environment:
      # Força diretamente os IPs de binding, independente da ordem das interfaces
      - N2_BIND_IP=${N2_IP}
      - N3_BIND_IP=${N3_IP}
      - N3_ADVERTISE_IP=${N3_IP}
EOF

echo "[INFO] Recriando apenas o container UERANSIM com override..."
docker compose -f docker-compose.yml -f ./overrides/ueransim-ifaces.override.yml up -d --force-recreate ueransim

echo "[OK] UERANSIM recriado com N2/N3 corretos."
