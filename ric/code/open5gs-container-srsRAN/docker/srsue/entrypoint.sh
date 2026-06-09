#!/bin/bash
# Entrypoint para srsUE em container.
# Inicia o srsue e, assim que a interface TUN da sessão PDU sobe com um IP do
# pool 5G, troca a rota default para a TUN — fazendo TODO o tráfego do UE sair
# pelo plano de dados 5G (e não pela rede ZMQ/Docker via eth0).
#
# ZMQ continua usando eth0 (rota on-link 172.31.250.0/24), então alterar a
# default não afeta a sincronização de I/Q com o gNB.

set -uo pipefail

TUN_IF="${TUN_IF:-tun_srsue}"

# Em segundo plano: aguarda a TUN ganhar IP do pool e aponta a default para ela.
configure_default_route() {
    for _ in $(seq 1 60); do
        if ip -o -4 addr show "$TUN_IF" 2>/dev/null | grep -q "inet "; then
            ip route del default 2>/dev/null || true
            if ip route replace default dev "$TUN_IF" 2>/dev/null; then
                echo "[entrypoint] rota default via $TUN_IF configurada (tráfego pela 5G)"
            else
                echo "[entrypoint] falha ao configurar rota default via $TUN_IF"
            fi
            return 0
        fi
        sleep 2
    done
    echo "[entrypoint] $TUN_IF não subiu a tempo; rota default inalterada"
}
configure_default_route &

# srsue precisa rodar em foreground como processo principal do container.
# Os argumentos (ex.: --ue.phy nr /config/ue.conf) vêm do 'command' do compose.
exec /usr/local/bin/srsue "$@"
