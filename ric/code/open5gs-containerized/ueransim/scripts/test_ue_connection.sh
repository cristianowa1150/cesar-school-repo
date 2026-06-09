#!/bin/bash

# Script para testar a conexão end-to-end do UE
# Autor: Jonas Augusto Kunzler
# Data: 2025-12-19
#
# Usa nomes reais dos containers do core (compose em core/) e lê logs em
# /var/log/open5gs/*.log quando necessário (Open5GS grava em arquivo).

set +e

UE_CONTAINER="${UE_CONTAINER:-ueransim}"
AMF_CONTAINER="${AMF_CONTAINER:-open5gs-amf-containerized}"
SMF_CONTAINER="${SMF_CONTAINER:-open5gs-smf-containerized}"
TEST_HOSTS=("8.8.8.8" "8.8.4.4" "1.1.1.1")
TEST_URLS=("http://ifconfig.me" "http://icanhazip.com")

# Logs internos do Open5GS (montados em core/logs no host)
amf_log_tail() {
  docker exec "$AMF_CONTAINER" sh -c 'tail -n 8000 /var/log/open5gs/amf.log 2>/dev/null' 2>/dev/null
}

smf_log_tail() {
  docker exec "$SMF_CONTAINER" sh -c 'tail -n 8000 /var/log/open5gs/smf.log 2>/dev/null' 2>/dev/null
}

ueransim_log_tail() {
  docker logs "$UE_CONTAINER" 2>&1 | tail -n 4000
}

echo "=========================================="
echo "Teste de Conexão End-to-End - UE"
echo "=========================================="
echo ""

if ! docker ps --format '{{.Names}}' | grep -qx "$UE_CONTAINER"; then
    echo "❌ Erro: Container $UE_CONTAINER não está rodando!"
    echo "   Execute: cd ueransim && ./scripts/up_ran.sh"
    exit 1
fi

echo "✅ Container $UE_CONTAINER está rodando"
echo ""

echo "📡 Verificando IP do UE..."
UE_ACTUAL_IP=$(docker exec "$UE_CONTAINER" ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")

if [ -z "$UE_ACTUAL_IP" ]; then
    echo "❌ Erro: UE não possui IP atribuído!"
    echo "   Verifique se a sessão PDU foi estabelecida corretamente."
    exit 1
fi

echo "✅ UE possui IP: $UE_ACTUAL_IP"
echo ""

echo "🔍 Teste 1: Ping para servidores DNS públicos"
echo "--------------------------------------------"
for host in "${TEST_HOSTS[@]}"; do
    echo -n "  Testando $host... "
    if docker exec "$UE_CONTAINER" ping -c 2 -W 2 "$host" > /dev/null 2>&1; then
        RTT=$(docker exec "$UE_CONTAINER" ping -c 2 -W 2 "$host" 2>&1 | grep "avg" | awk -F'/' '{print $5}')
        echo "✅ OK (RTT médio: ${RTT}ms)"
    else
        echo "❌ FALHOU"
    fi
done
echo ""

echo "🔍 Teste 2: Resolução DNS"
echo "--------------------------------------------"
TEST_DOMAIN="google.com"
DNS_OK=0
# Resolver padrão do container costuma estar vazio; testar com servidor explícito
for NS in 8.8.8.8 1.1.1.1; do
  echo -n "  Resolvendo $TEST_DOMAIN via $NS... "
  if docker exec "$UE_CONTAINER" nslookup "$TEST_DOMAIN" "$NS" > /dev/null 2>&1; then
    IP=$(docker exec "$UE_CONTAINER" nslookup "$TEST_DOMAIN" "$NS" 2>&1 | grep -A2 "Name:" | grep "Address:" | awk '{print $2}' | head -1)
    echo "✅ OK (IP: $IP)"
    DNS_OK=1
    break
  else
    echo "❌"
  fi
done
if [ "$DNS_OK" -eq 0 ]; then
  echo -n "  Tentativa alternativa (getent/ping nome)... "
  if docker exec "$UE_CONTAINER" getent hosts "$TEST_DOMAIN" > /dev/null 2>&1; then
    echo "✅ OK ($(docker exec "$UE_CONTAINER" getent hosts "$TEST_DOMAIN" | awk '{print $1}'))"
    DNS_OK=1
  elif docker exec "$UE_CONTAINER" ping -c 1 -W 2 "$TEST_DOMAIN" > /dev/null 2>&1; then
    echo "✅ OK (ping ao FQDN)"
    DNS_OK=1
  else
    echo "⚠️  DNS não validado (ICMP aos IPs públicos ainda pode estar OK sem DNS no UE)"
  fi
fi
echo ""

echo "🔍 Teste 3: Acesso HTTP"
echo "--------------------------------------------"
HTTP_OK=0
for url in "${TEST_URLS[@]}"; do
    echo -n "  Testando $url... "
    OUT=""
    if docker exec "$UE_CONTAINER" sh -c 'command -v curl >/dev/null 2>&1'; then
      OUT=$(docker exec "$UE_CONTAINER" curl -fsS --max-time 12 -L "$url" 2>/dev/null | head -1)
    elif docker exec "$UE_CONTAINER" sh -c 'command -v wget >/dev/null 2>&1'; then
      OUT=$(docker exec "$UE_CONTAINER" wget -q --timeout=12 -O- "$url" 2>/dev/null | head -1)
    fi
    if [ -n "$OUT" ]; then
        echo "✅ OK (resposta: ${OUT:0:60}...)"
        HTTP_OK=1
    else
        echo "❌ FALHOU"
    fi
done
if [ "$HTTP_OK" -eq 0 ]; then
  echo "  💡 Se o ping aos IPs funcionar, falha HTTP pode ser ausência de curl/wget no container ou bloqueio HTTP."
fi
echo ""

echo "🔍 Teste 4: Verificar rota padrão (container UERANSIM)"
echo "--------------------------------------------"
DEFAULT_GW=$(docker exec "$UE_CONTAINER" ip route 2>/dev/null | grep default | awk '{print $3}' || echo "não encontrado")
echo "  Gateway padrão: $DEFAULT_GW"
echo ""

echo "🔍 Teste 5: Conectividade com UPF"
echo "--------------------------------------------"
UPF_IP="10.40.0.21"
echo -n "  Testando conectividade com UPF ($UPF_IP)... "
if docker exec "$UE_CONTAINER" ping -c 1 -W 1 "$UPF_IP" > /dev/null 2>&1; then
    echo "✅ OK"
else
    echo "⚠️  Não acessível diretamente (normal — UPF pode não responder ICMP)"
fi
echo ""

echo "🔍 Teste 6: Verificar sessão PDU e registro de UE"
echo "--------------------------------------------"
AMF_LOG=$(amf_log_tail)
SMF_LOG=$(smf_log_tail)

echo "  Verificando conexão N2 (AMF <-> gNB)..."
if echo "$AMF_LOG" | grep -qiE 'gNB-N2 accepted|NG[ -]?Setup|SetupResponse|ran-ue-id'; then
    echo "  ✅ Conexão N2 / NGAP indicada nos logs do AMF"
elif ueransim_log_tail | grep -qiE 'NG Setup procedure is successful|NGSetup|N2 connection'; then
    echo "  ✅ Conexão N2 indicada nos logs do UERANSIM"
else
    echo "  ⚠️  Conexão N2 não encontrada nos logs (confira amf.log e docker logs ueransim)"
fi

echo "  Verificando associação PFCP (SMF <-> UPF)..."
if echo "$SMF_LOG" | grep -qi 'PFCP associated'; then
    echo "  ✅ Associação PFCP estabelecida (SMF <-> UPF)"
else
    echo "  ⚠️  Associação PFCP não encontrada em smf.log (confira se o core está ativo)"
fi

AMF_CONTEXT_ERROR=$(ueransim_log_tail | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
if [ "${AMF_CONTEXT_ERROR:-0}" -gt 0 ] 2>/dev/null; then
    echo "  ❌ Problema detectado: AMF context not found ($AMF_CONTEXT_ERROR ocorrência(s))"
    echo "     Execute: ../core/scripts/test-system-status.sh para mais detalhes"
else
    UE_REG_STATE=$(ueransim_log_tail | grep "UE switches to state" | tail -1 | grep -oP "\[MM-[^\]]+\]" || echo "")
    if echo "$UE_REG_STATE" | grep -q "REGISTERED"; then
        echo "  ✅ UE registrado no AMF: $UE_REG_STATE"
    elif [ -n "$UE_ACTUAL_IP" ] && docker exec "$UE_CONTAINER" ping -c 1 -W 1 8.8.8.8 > /dev/null 2>&1; then
        echo "  ⚠️  Registro não encontrado nos logs, mas UE tem IP e conectividade"
    else
        echo "  ⚠️  UE não está registrado"
    fi
fi

echo ""
echo "  💡 Dica: ../core/scripts/test-system-status.sh — verificação detalhada"
echo ""

echo "=========================================="
echo "Resumo dos Testes"
echo "=========================================="
echo ""
echo "IP do UE: $UE_ACTUAL_IP"
echo "Gateway: $DEFAULT_GW"
echo ""
echo "✅ Testes de conectividade básica concluídos!"
echo ""
