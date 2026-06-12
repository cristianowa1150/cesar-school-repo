#!/bin/bash

# Script para testar failover entre UPF-A e UPF-B
# Autor: Jonas Augusto Kunzler
# Data: 2025-12-19

# Não usar set -e para permitir tratamento de erros
set +e

# Após unificação, UE e gNB rodam no mesmo serviço/container `ueransim`
UE_CONTAINER="ueransim"
UPF_A_CONTAINER="upf-a"
UPF_B_CONTAINER="upf-b"
SMF_CONTAINER="smf"
TEST_HOST="8.8.8.8"
TEST_DURATION=30  # segundos de teste contínuo
PING_INTERVAL=2   # segundos entre pings

echo "=========================================="
echo "Teste de Failover UPF"
echo "Open5GS Containerized"
echo "=========================================="
echo ""

# Verificar se os containers estão rodando
MISSING_CONTAINERS=()
for container in "$UE_CONTAINER" "$UPF_A_CONTAINER" "$UPF_B_CONTAINER" "$SMF_CONTAINER"; do
    if ! docker compose ps | grep -q "$container.*Up"; then
        MISSING_CONTAINERS+=("$container")
    fi
done

if [ ${#MISSING_CONTAINERS[@]} -gt 0 ]; then
    echo "❌ Erro: Containers não estão rodando:"
    for container in "${MISSING_CONTAINERS[@]}"; do
        echo "   - $container"
    done
    echo ""
    echo "Execute: ./scripts/up.sh"
    exit 1
fi

echo "✅ Todos os containers necessários estão rodando"
echo ""

# Obter IP do UE
UE_IP=$(docker compose exec $UE_CONTAINER ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
if [ -z "$UE_IP" ]; then
    echo "❌ Erro: UE não possui IP atribuído!"
    echo ""
    echo "Isso indica que:"
    echo "  - UE não está registrado no AMF, OU"
    echo "  - Sessão PDU não foi estabelecida"
    echo ""
    echo "Verifique:"
    echo "  - Execute: ./scripts/test-system-status.sh"
    echo "  - Logs do UE: docker compose logs $UE_CONTAINER"
    exit 1
fi

echo "📡 UE IP: $UE_IP"
echo ""

# Verificar se há problema de AMF context que pode afetar o teste (logs do container único)
AMF_CONTEXT_ERROR=$(docker compose logs ueransim 2>&1 | grep -c "AMF context not found" 2>/dev/null | head -1 || echo "0")
if [ "$AMF_CONTEXT_ERROR" -gt 0 ] 2>/dev/null; then
    echo "⚠️  Aviso: Problema de 'AMF context not found' detectado"
    echo "   Isso pode afetar o registro de novos UEs"
    echo "   O teste continuará, mas pode haver problemas de conectividade"
    echo ""
fi

# Função para verificar qual UPF está ativo
# Usa múltiplos métodos para determinar qual UPF está sendo usada
check_active_upf() {
    # Verificar status dos containers primeiro
    # Usar docker compose ps com filtro para verificar se está rodando
    UPF_A_RUNNING="no"
    UPF_B_RUNNING="no"
    
    if docker compose ps $UPF_A_CONTAINER 2>/dev/null | grep -q "Up"; then
        UPF_A_RUNNING="yes"
    fi
    
    if docker compose ps $UPF_B_CONTAINER 2>/dev/null | grep -q "Up"; then
        UPF_B_RUNNING="yes"
    fi
    
    # Se apenas uma está rodando, essa é a ativa (prioridade sobre logs)
    if [ "$UPF_A_RUNNING" = "no" ] && [ "$UPF_B_RUNNING" = "yes" ]; then
        echo "UPF-B"
        return 0
    elif [ "$UPF_B_RUNNING" = "no" ] && [ "$UPF_A_RUNNING" = "yes" ]; then
        echo "UPF-A"
        return 0
    elif [ "$UPF_A_RUNNING" = "no" ] && [ "$UPF_B_RUNNING" = "no" ]; then
        echo "UNKNOWN (nenhuma UPF rodando)"
        return 0
    fi
    
    # Obter logs do SMF diretamente do arquivo de log (mais confiável, sem códigos ANSI)
    # Tentar ler do arquivo de log primeiro, depois fallback para docker compose logs
    SMF_LOG_FILE="./logs/smf/smf.log"
    if [ -f "$SMF_LOG_FILE" ]; then
        ALL_ASSOCS=$(grep "PFCP associated" "$SMF_LOG_FILE" 2>/dev/null || echo "")
    fi
    
    # Se não encontrou no arquivo, usar docker compose logs (nome do serviço)
    if [ -z "$ALL_ASSOCS" ]; then
        ALL_ASSOCS=$(docker compose logs $SMF_CONTAINER 2>&1 | grep "PFCP associated" || echo "")
    fi
    
    if [ -z "$ALL_ASSOCS" ]; then
        echo "UNKNOWN"
        return 0
    fi
    
    # Buscar última linha de associação
    LAST_ASSOC=$(echo "$ALL_ASSOCS" | tail -1)
    
    # Extrair IP da última linha usando grep -o (formato: PFCP associated [10.40.0.21]:8805)
    LAST_IP=$(echo "$LAST_ASSOC" | grep -oE "10\.40\.0\.2[12]" | head -1)
    
    # Determinar qual UPF baseado no IP extraído
    if [ "$LAST_IP" = "10.40.0.21" ]; then
        echo "UPF-A"
    elif [ "$LAST_IP" = "10.40.0.22" ]; then
        echo "UPF-B"
    else
        # Se não conseguiu extrair IP, verificar se ambas estão associadas
        UPF_A_COUNT=$(echo "$ALL_ASSOCS" | grep -c "10.40.0.21" 2>/dev/null || echo "0")
        UPF_B_COUNT=$(echo "$ALL_ASSOCS" | grep -c "10.40.0.22" 2>/dev/null || echo "0")
        
        if [ "$UPF_A_COUNT" -gt 0 ] && [ "$UPF_B_COUNT" -gt 0 ]; then
            # Ambas têm associação - verificar qual foi a última
            UPF_A_LAST=$(echo "$ALL_ASSOCS" | grep "10.40.0.21" | tail -1)
            UPF_B_LAST=$(echo "$ALL_ASSOCS" | grep "10.40.0.22" | tail -1)
            
            # Comparar qual aparece por último na lista completa
            UPF_A_POS=$(echo "$ALL_ASSOCS" | grep -n "10.40.0.21" | tail -1 | cut -d: -f1)
            UPF_B_POS=$(echo "$ALL_ASSOCS" | grep -n "10.40.0.22" | tail -1 | cut -d: -f1)
            
            if [ -n "$UPF_A_POS" ] && [ -n "$UPF_B_POS" ]; then
                if [ "$UPF_A_POS" -gt "$UPF_B_POS" ] 2>/dev/null; then
                    echo "UPF-A"
                elif [ "$UPF_B_POS" -gt "$UPF_A_POS" ] 2>/dev/null; then
                    echo "UPF-B"
                else
                    echo "BOTH (ambas associadas)"
                fi
            else
                echo "BOTH (ambas associadas)"
            fi
        elif [ "$UPF_A_COUNT" -gt 0 ]; then
            echo "UPF-A"
        elif [ "$UPF_B_COUNT" -gt 0 ]; then
            echo "UPF-B"
        else
            echo "UNKNOWN"
        fi
    fi
}

# Função para testar conectividade
test_connectivity() {
    if docker compose exec $UE_CONTAINER ping -c 1 -W 2 $TEST_HOST > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Função para parar UPF
stop_upf() {
    local upf=$1
    echo "🛑 Parando $upf..."
    docker compose stop $upf > /dev/null 2>&1
    sleep 3
}

# Função para iniciar UPF
start_upf() {
    local upf=$1
    echo "▶️  Iniciando $upf..."
    docker compose start $upf > /dev/null 2>&1
    sleep 5
}

# Teste 1: Verificar estado inicial
echo "=========================================="
echo "Teste 1: Estado Inicial"
echo "=========================================="
echo ""

echo "Verificando conectividade inicial..."
if test_connectivity; then
    echo "✅ Conectividade OK"
    ACTIVE_UPF=$(check_active_upf)
    echo "📊 UPF ativo: $ACTIVE_UPF"
    echo "  (Nota: Open5GS mantém associações PFCP com ambas UPFs. A seleção real ocorre durante criação de sessão PDU.)"
else
    echo "❌ Conectividade falhou antes do teste!"
    exit 1
fi
echo ""

# Teste 2: Failover UPF-A -> UPF-B
echo "=========================================="
echo "Teste 2: Failover UPF-A -> UPF-B"
echo "=========================================="
echo ""

echo "📊 Estado antes do failover:"
ACTIVE_UPF=$(check_active_upf)
echo "  UPF ativo: $ACTIVE_UPF"
echo ""

if [ "$ACTIVE_UPF" = "UPF-A" ] || [ "$ACTIVE_UPF" = "UNKNOWN" ] || [ "$ACTIVE_UPF" = "BOTH" ]; then
    echo "Parando UPF-A para forçar failover para UPF-B..."
    stop_upf $UPF_A_CONTAINER
    
    echo ""
    echo "Aguardando failover (15 segundos para SMF detectar falha PFCP)..."
    for i in {1..15}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    echo ""
    echo "📊 Estado após parar UPF-A:"
    NEW_ACTIVE_UPF=$(check_active_upf)
    echo "  UPF ativo: $NEW_ACTIVE_UPF"
    
    echo ""
    echo "Testando conectividade após failover..."
    FAILOVER_SUCCESS=false
    MAX_ATTEMPTS=15
    for i in $(seq 1 $MAX_ATTEMPTS); do
        if test_connectivity; then
            echo "  ✅ Ping $i/$MAX_ATTEMPTS: OK"
            FAILOVER_SUCCESS=true
            break
        else
            echo "  ⏳ Ping $i/$MAX_ATTEMPTS: Aguardando failover..."
            sleep 2
        fi
    done
    
    if [ "$FAILOVER_SUCCESS" = true ]; then
        echo ""
        echo "✅ Failover bem-sucedido! Conectividade mantida."
    else
        echo ""
        echo "❌ Failover falhou! Conectividade perdida."
    fi
    
    echo ""
    echo "Reiniciando UPF-A..."
    start_upf $UPF_A_CONTAINER
    sleep 10
else
    echo "⚠️  UPF-A não está ativo, pulando teste de failover A->B"
fi
echo ""

# Teste 3: Failover UPF-B -> UPF-A
echo "=========================================="
echo "Teste 3: Failover UPF-B -> UPF-A"
echo "=========================================="
echo ""

echo "📊 Estado antes do failover:"
ACTIVE_UPF=$(check_active_upf)
echo "  UPF ativo: $ACTIVE_UPF"
echo ""

# Verificar se ambas UPFs estão rodando antes de executar o teste
UPF_A_RUNNING_NOW=$(docker compose ps $UPF_A_CONTAINER 2>/dev/null | grep -q "Up" && echo "yes" || echo "no")
UPF_B_RUNNING_NOW=$(docker compose ps $UPF_B_CONTAINER 2>/dev/null | grep -q "Up" && echo "yes" || echo "no")

if [ "$UPF_A_RUNNING_NOW" = "yes" ] && [ "$UPF_B_RUNNING_NOW" = "yes" ]; then
    # Ambas estão rodando - executar teste de failover B->A
    echo "Parando UPF-B para forçar failover para UPF-A..."
    stop_upf $UPF_B_CONTAINER
    
    echo ""
    echo "Aguardando failover (15 segundos para SMF detectar falha PFCP)..."
    for i in {1..15}; do
        echo -n "."
        sleep 1
    done
    echo ""
    
    echo ""
    echo "📊 Estado após parar UPF-B:"
    NEW_ACTIVE_UPF=$(check_active_upf)
    echo "  UPF ativo: $NEW_ACTIVE_UPF"
    
    echo ""
    echo "Testando conectividade após failover..."
    FAILOVER_SUCCESS=false
    MAX_ATTEMPTS=15
    for i in $(seq 1 $MAX_ATTEMPTS); do
        if test_connectivity; then
            echo "  ✅ Ping $i/$MAX_ATTEMPTS: OK"
            FAILOVER_SUCCESS=true
            break
        else
            echo "  ⏳ Ping $i/$MAX_ATTEMPTS: Aguardando failover..."
            sleep 2
        fi
    done
    
    if [ "$FAILOVER_SUCCESS" = true ]; then
        echo ""
        echo "✅ Failover bem-sucedido! Conectividade mantida."
    else
        echo ""
        echo "❌ Failover falhou! Conectividade perdida."
    fi
    
    echo ""
    echo "Reiniciando UPF-B..."
    start_upf $UPF_B_CONTAINER
    sleep 10
else
    echo "⚠️  UPF-B não está rodando, pulando teste de failover B->A"
    echo "   (Execute: docker compose start upf-b para habilitar este teste)"
fi
echo ""

# Teste 4: Teste de conectividade contínua
echo "=========================================="
echo "Teste 4: Conectividade Contínua"
echo "=========================================="
echo ""

echo "Testando conectividade contínua por ${TEST_DURATION} segundos..."
SUCCESS_COUNT=0
FAIL_COUNT=0
TOTAL_TESTS=$((TEST_DURATION / PING_INTERVAL))

for i in $(seq 1 $TOTAL_TESTS); do
    if test_connectivity; then
        SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
        echo -n "✅ "
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
        echo -n "❌ "
    fi
    
    if [ $((i % 10)) -eq 0 ]; then
        echo " ($i/$TOTAL_TESTS)"
    fi
    
    sleep $PING_INTERVAL
done
echo ""
echo ""

# Resumo final
echo "=========================================="
echo "Resumo dos Testes de Failover"
echo "=========================================="
echo ""
echo "Testes de conectividade contínua:"
echo "  ✅ Sucessos: $SUCCESS_COUNT/$TOTAL_TESTS"
echo "  ❌ Falhas: $FAIL_COUNT/$TOTAL_TESTS"
# Calcular taxa de sucesso sem depender de bc
if [ "$TOTAL_TESTS" -gt 0 ]; then
    SUCCESS_RATE=$((SUCCESS_COUNT * 100 / TOTAL_TESTS))
    echo "  📊 Taxa de sucesso: ${SUCCESS_RATE}%"
else
    echo "  📊 Taxa de sucesso: N/A (nenhum teste executado)"
fi
echo ""

# Verificar estado final dos UPFs
echo "Estado final dos UPFs:"
if docker compose ps | grep -q "$UPF_A_CONTAINER.*Up"; then
    echo "  ✅ UPF-A: Rodando"
else
    echo "  ❌ UPF-A: Parado"
fi

if docker compose ps | grep -q "$UPF_B_CONTAINER.*Up"; then
    echo "  ✅ UPF-B: Rodando"
else
    echo "  ❌ UPF-B: Parado"
fi
echo ""

# Garantir que ambos os UPFs estão rodando ao final
if ! docker compose ps | grep -q "$UPF_A_CONTAINER.*Up"; then
    echo "Reiniciando UPF-A..."
    start_upf $UPF_A_CONTAINER
fi

if ! docker compose ps | grep -q "$UPF_B_CONTAINER.*Up"; then
    echo "Reiniciando UPF-B..."
    start_upf $UPF_B_CONTAINER
fi

echo "✅ Testes de failover concluídos!"
echo ""
echo "💡 Informações Adicionais:"
echo "  - Para verificação detalhada do sistema: ./scripts/test-system-status.sh"
echo "  - Para teste de conectividade: ./scripts/test_ue_connection.sh"
echo "  - Para verificar logs: docker compose logs <serviço>"
echo ""
