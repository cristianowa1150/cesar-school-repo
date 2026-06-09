#!/bin/sh
set -eu

AMF_IP="${AMF_IP:-10.100.200.16}"

echo "[wait] srsCU: aguardando AMF (${AMF_IP})..."
for i in $(seq 1 80); do
  ip link show eth0 >/dev/null 2>&1 &&
  ip route get "${AMF_IP}" >/dev/null 2>&1 &&
  ping -c1 -W1 "${AMF_IP}" >/dev/null 2>&1 && break
  sleep 0.2
done

echo "[debug] ip a:"; ip a
echo "[debug] ip r:"; ip r

# F1-U e NG-U (GTP-U) usam a mesma porta UDP (2152) por defeito. Com o mesmo bind_addr,
# o segundo socket falha ("Address already in use"). IP extra na mesma /24 para o F1-U.
CU_F1U_IP="${CU_F1U_IP:-10.100.200.61}"
if ip addr add "${CU_F1U_IP}/24" dev eth0 2>/dev/null; then
  echo "[info] IP extra para F1-U: ${CU_F1U_IP}/24"
else
  echo "[info] IP ${CU_F1U_IP} já presente ou não aplicável; seguindo."
fi

BIN="$(command -v srscu || true)"
[ -x "${BIN:-}" ] || { echo "FATAL: srscu não encontrado (imagem srsRAN incompleta?)"; exit 127; }

if [ "${CU_AUTO_START:-0}" = "0" ]; then
  echo "[info] CU_AUTO_START=0: srscu NÃO foi iniciado (arranque manual)."
  echo "  No host:  ./scripts/start-cu.sh"
  echo "  ou:       docker exec -it srsran-cu srscu -c /etc/srsran/cu.yml"
  echo "  O container fica em espera (idle)."
  exec tail -f /dev/null
fi

exec "$BIN" -c /etc/srsran/cu.yml
