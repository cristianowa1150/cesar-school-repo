#!/bin/bash

# Script de inicialização do PCF
# Configura /etc/hosts e aguarda MongoDB estar pronto

set -e

# Adicionar entrada em /etc/hosts para resolver "mongo" como "mongodb"
if ! grep -q "10.10.0.20 mongo" /etc/hosts 2>/dev/null; then
    echo "10.10.0.20 mongo mongodb" >> /etc/hosts
fi

# Aguardar MongoDB estar acessível
echo "Aguardando MongoDB estar pronto..."
for i in {1..30}; do
    if ping -c 1 mongodb > /dev/null 2>&1; then
        echo "MongoDB está acessível"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "Erro: MongoDB não está acessível após 30 tentativas"
        exit 1
    fi
    sleep 1
done

# Aguardar um pouco mais para garantir que MongoDB está totalmente pronto
sleep 3

# Executar PCF
exec /opt/open5gs/bin/open5gs-pcfd -c /etc/open5gs/pcf.yaml
