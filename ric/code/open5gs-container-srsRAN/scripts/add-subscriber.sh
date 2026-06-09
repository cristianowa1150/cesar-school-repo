#!/bin/bash

# Script para adicionar subscriber ao MongoDB
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-16

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Adicionar Subscriber ao MongoDB"
echo "=========================================="
echo ""

# Verificar se MongoDB está rodando
if ! docker compose ps mongodb | grep -q "Up"; then
    echo -e "${RED}❌ MongoDB não está rodando${NC}"
    echo "Execute: docker compose up -d mongodb"
    exit 1
fi

# Dados do subscriber (do arquivo ue.yaml)
IMSI="001010000000001"
MSISDN="33638060000"
K="465B5CE8B199B49FAA5F0A2EE238A6B0"
OP="E8ED289DEBA952E4283B54E88E6183B8"
OPC="E8ED289DEBA952E4283B54E88E6183B8"
AMF="8000"

echo -e "${YELLOW}Adicionando subscriber:${NC}"
echo "  IMSI: $IMSI"
echo "  MSISDN: $MSISDN"
echo ""

# Verificar se já existe
EXISTS=$(docker compose exec -T mongodb mongosh open5gs --quiet --eval "db.subscribers.countDocuments({imsi: '$IMSI'})" 2>/dev/null | tr -d '\n' || echo "0")

if [ "$EXISTS" != "0" ]; then
    echo -e "${YELLOW}⚠️  Subscriber já existe. Removendo...${NC}"
    docker compose exec -T mongodb mongosh open5gs --quiet --eval "db.subscribers.deleteOne({imsi: '$IMSI'})" >/dev/null 2>&1
fi

# Adicionar subscriber
echo -e "${YELLOW}Inserindo subscriber no MongoDB...${NC}"
docker compose exec -T mongodb mongosh open5gs --quiet --eval "
db.subscribers.insertOne({
    imsi: '$IMSI',
    msisdn: '$MSISDN',
    'subscribed_ue_ambr': {
        'uplink': {'value': 1000000000, 'unit': 0},
        'downlink': {'value': 2000000000, 'unit': 0}
    },
    'slice': [{'sst': 1, 'default_indicator': true, 'session': [{'name': 'internet', 'type': 3, 'pcc_rule': [], 'ambr': {'uplink': {'value': 1000000000, 'unit': 0}, 'downlink': {'value': 2000000000, 'unit': 0}}, 'qos': {'index': 9, 'arp': {'priority_level': 8, 'pre_emption_capability': 1, 'pre_emption_vulnerability': 1}}}]}],
    'security': {
        'k': '$K',
        'op': '$OP',
        'opc': '$OPC',
        'amf': '$AMF'
    },
    'ambr': {
        'uplink': {'value': 1000000000, 'unit': 0},
        'downlink': {'value': 2000000000, 'unit': 0}
    },
    'access_restriction_data': 32,
    'subscriber_status': 0,
    'network_access_mode': 0,
    'subscribed_rau_tau_timer': 600,
    'ue_usage_setting': 0
})
" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Subscriber adicionado com sucesso!${NC}"
    echo ""
    echo "Verificando subscriber:"
    docker compose exec -T mongodb mongosh open5gs --quiet --eval "db.subscribers.findOne({imsi: '$IMSI'}, {imsi: 1, msisdn: 1, 'nssai': 1})" 2>/dev/null | head -10
    echo ""
    echo -e "${YELLOW}💡 Dica: Reinicie o UE para tentar registrar novamente:${NC}"
    echo "  docker compose restart ueransim-ue"
else
    echo -e "${RED}❌ Erro ao adicionar subscriber${NC}"
    exit 1
fi

