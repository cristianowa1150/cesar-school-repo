# shellcheck shell=bash
# Carregado por start-du-after-ue.sh e run-du.sh — não executar diretamente.
# No Linux, host.docker.internal por vezes não encaminha TCP para o srsUE no host;
# substituímos pelo Gateway IPv4 da rede free5gc-privnet (mesmo efeito que o Docker usa).

prepare_du_yaml_for_container() {
  local ROOT="$1"
  local CFG="$2"
  local NET="${ZMQ_DOCKER_NETWORK:-free5gc-privnet}"
  local SRC="${ROOT}/configs/${CFG}"
  local GW

  if [ ! -f "$SRC" ]; then
    echo "/etc/srsran/${CFG}"
    return
  fi

  GW=$(docker network inspect "$NET" -f '{{(index .IPAM.Config 0).Gateway}}' 2>/dev/null || true)
  if [[ -n "$GW" ]] && [[ "$GW" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && grep -qF 'host.docker.internal' "$SRC"; then
    echo "ZMQ: rx_port usa gateway Docker ${GW} (rede ${NET}) em vez de host.docker.internal — UL para o srsUE no host." >&2
    sed "s/host.docker.internal/${GW}/g" "$SRC" > /tmp/srsran-du-runtime.yml
    docker cp /tmp/srsran-du-runtime.yml srsran-du:/tmp/du-runtime.yml
    rm -f /tmp/srsran-du-runtime.yml
    echo "/tmp/du-runtime.yml"
  else
    echo "/etc/srsran/${CFG}"
  fi
}
