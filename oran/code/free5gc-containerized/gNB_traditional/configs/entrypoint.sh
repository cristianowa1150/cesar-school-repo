#!/bin/sh
set -eu

AMF_IP="${AMF_IP:-10.100.200.16}"

echo "$(date '+%Y-%m-%d %H:%M:%S')[wait] waiting for eth0 + route + AMF reachability (${AMF_IP})..."
for i in $(seq 1 80); do
  ip link show eth0 >/dev/null 2>&1 &&
  ip route get "${AMF_IP}" >/dev/null 2>&1 &&
  ping -c1 -W1 "${AMF_IP}" >/dev/null 2>&1 && break
  sleep 0.2
done

echo "$(date '+%Y-%m-%d %H:%M:%S')[debug] ip a:"; ip a
echo "$(date '+%Y-%m-%d %H:%M:%S')[debug] ip r:"; ip r

BIN="$(command -v gnb || true)"
[ -x "${BIN:-}" ] || { echo "$(date '+%Y-%m-%d %H:%M:%S')[FATAL] gnb not found in PATH"; exit 127; }

CONFIG="${GNB_CONFIG:-gnb-zmq-srsue.yml}"

if [ "${GNB_AUTO_START:-1}" = "0" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S')[info] GNB_AUTO_START=0: container stays up. Run manually: gnb -c /etc/srsran/${CONFIG}"
  exec tail -f /dev/null
fi

echo "$(date '+%Y-%m-%d %H:%M:%S')[start] gnb -c /etc/srsran/${CONFIG}"
exec "$BIN" -c /etc/srsran/"${CONFIG}"
