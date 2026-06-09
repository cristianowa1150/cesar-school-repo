#!/usr/bin/env bash
# Biblioteca: containers RAN que terminam N2 (NGAP) para o AMF.
# O core roda em outro compose; estes nomes são estáveis nos docker-compose de gNB_*.
#
# Suporta **vários** N2 ao mesmo tempo (ex.: srsran-gnb-tradicional + srsran-cu), desde que
# cada um tenha Global gNB ID distinto na config YAML (gnb_id / pci).

RAN_N2_KNOWN_ORDER=(srsran-cu srsran-gnb-tradicional srsran-gnb)

list_ran_n2_containers() {
  RAN_N2_CONTAINERS=()
  local c
  for c in "${RAN_N2_KNOWN_ORDER[@]}"; do
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$c"; then
      RAN_N2_CONTAINERS+=("$c")
    fi
  done
  [ "${#RAN_N2_CONTAINERS[@]}" -gt 0 ]
}

# Compatibilidade: primeiro N2 ativo (ordem em RAN_N2_KNOWN_ORDER).
detect_ran_n2_container() {
  RAN_N2_CONTAINER=""
  list_ran_n2_containers || return 1
  RAN_N2_CONTAINER="${RAN_N2_CONTAINERS[0]}"
  return 0
}

ran_n2_ip() {
  detect_ran_n2_container || return 1
  docker exec "$RAN_N2_CONTAINER" ip -4 -o addr show eth0 2>/dev/null \
    | awk '{print $4}' | cut -d/ -f1 | head -1
}

# Todos os N2 ativos (IPs eth0), um por linha.
ran_n2_all_ips() {
  list_ran_n2_containers || return 1
  local c ip
  for c in "${RAN_N2_CONTAINERS[@]}"; do
    ip=$(docker exec "$c" ip -4 -o addr show eth0 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -1)
    [ -n "$ip" ] && echo "$ip"
  done
}

# Logs concatenados (marcadores por container) para grep agregado ou debug.
ran_n2_logs() {
  list_ran_n2_containers || return 1
  local c
  for c in "${RAN_N2_CONTAINERS[@]}"; do
    echo "======== docker logs $c ========"
    docker logs "$c" 2>&1
  done
}
