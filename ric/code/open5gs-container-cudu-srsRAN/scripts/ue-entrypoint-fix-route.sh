#!/bin/bash

# Script para ser executado no entrypoint do UE
# Configura a rota padrão para usar a sessão PDU após o IP ser atribuído
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-16

set +e

OGSTUN_GW="10.60.0.1"
PDU_INTERFACE="eth1"
MAX_WAIT=60  # Esperar até 60 segundos pelo IP
WAIT_INTERVAL=2

echo "Aguardando IP da sessão PDU na interface $PDU_INTERFACE..."

# Aguardar até que o IP seja atribuído
for i in $(seq 1 $((MAX_WAIT / WAIT_INTERVAL))); do
    UE_IP=$(ip addr show $PDU_INTERFACE 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
    
    if [ -n "$UE_IP" ]; then
        echo "IP da sessão PDU detectado: $UE_IP"
        
        # Verificar se gateway ogstun é acessível
        if ping -c 1 -W 1 $OGSTUN_GW >/dev/null 2>&1; then
            # Verificar rota padrão atual
            CURRENT_GW=$(ip route show default 2>/dev/null | grep -oP 'via \K[\d.]+' | head -1 || echo "")
            CURRENT_DEV=$(ip route show default 2>/dev/null | grep -oP 'dev \K\w+' | head -1 || echo "")
            
            # Se a rota padrão não aponta para ogstun, corrigir
            if [ "$CURRENT_GW" != "$OGSTUN_GW" ] || [ "$CURRENT_DEV" != "$PDU_INTERFACE" ]; then
                echo "Configurando rota padrão para usar sessão PDU..."
                ip route del default 2>/dev/null || true
                ip route add default via $OGSTUN_GW dev $PDU_INTERFACE 2>/dev/null
                
                if [ $? -eq 0 ]; then
                    echo "✅ Rota padrão configurada: default via $OGSTUN_GW dev $PDU_INTERFACE"
                else
                    echo "⚠️  Não foi possível configurar rota padrão (pode precisar de privilégios)"
                fi
            else
                echo "✅ Rota padrão já está correta"
            fi
            break
        else
            echo "Gateway ogstun ainda não acessível, aguardando..."
        fi
    fi
    
    sleep $WAIT_INTERVAL
done

# Executar o comando original do entrypoint
exec "$@"

