#!/bin/bash
#
# Script para corrigir problemas do UPF
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-20

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_DIR"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "=========================================="
echo "Corrigir Problemas do UPF"
echo "=========================================="
echo ""

# Verificar se UPF está rodando
if ! docker compose ps free5gc-upf | grep -q "Up"; then
    echo -e "${YELLOW}UPF não está rodando. Verificando problemas...${NC}"
    echo ""
    
    # Verificar logs do UPF
    echo "📋 Últimos logs do UPF:"
    docker compose logs free5gc-upf --tail 20
    echo ""
    
    # Verificar se há problemas de permissão ou configuração
    echo "🔧 Tentando reiniciar UPF..."
    docker compose restart free5gc-upf
    sleep 5
    
    if docker compose ps free5gc-upf | grep -q "Up"; then
        echo -e "${GREEN}✅ UPF reiniciado com sucesso${NC}"
    else
        echo -e "${RED}❌ Falha ao reiniciar UPF${NC}"
        echo ""
        echo "Tentando recriar o container..."
        docker compose up -d --force-recreate free5gc-upf
        sleep 5
        
        if docker compose ps free5gc-upf | grep -q "Up"; then
            echo -e "${GREEN}✅ UPF recriado e iniciado${NC}"
        else
            echo -e "${RED}❌ Falha ao recriar UPF${NC}"
            echo ""
            echo "💡 Verifique:"
            echo "  - Logs: docker compose logs free5gc-upf"
            echo "  - Configuração: config/upfcfg.yaml"
            echo "  - Script iptables: config/upf-iptables.sh"
            echo "  - Permissões: O container precisa de NET_ADMIN"
            echo "  - Módulo gtp5g: Verifique se está carregado no host"
            exit 1
        fi
    fi
else
    echo -e "${GREEN}✅ UPF está rodando${NC}"
fi

echo ""
echo -e "${BLUE}🔍 Verificando interface upfgtp...${NC}"

# Verificar se a interface upfgtp existe e tem IP
UPFGTP_EXISTS=$(docker compose exec -T free5gc-upf ip link show upfgtp 2>/dev/null | wc -l | tr -d ' \n\r')
UPFGTP_EXISTS=${UPFGTP_EXISTS:-0}

if [ "$UPFGTP_EXISTS" -gt 0 ]; then
    echo -e "${GREEN}✅ Interface upfgtp existe${NC}"
    
    # Verificar se tem IPv4
    UPFGTP_IPV4=$(docker compose exec -T free5gc-upf ip addr show upfgtp | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1)
    
    if [ -z "$UPFGTP_IPV4" ]; then
        echo -e "${YELLOW}⚠️  Interface upfgtp não tem IPv4. Corrigindo...${NC}"
        
        # Obter o IP do container
        UPF_IP=$(docker compose exec -T free5gc-upf ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
        
        if [ -n "$UPF_IP" ]; then
            echo -e "${BLUE}   Atribuindo IP $UPF_IP à interface upfgtp...${NC}"
            docker compose exec -T free5gc-upf ip addr add "$UPF_IP/32" dev upfgtp 2>/dev/null || true
            docker compose exec -T free5gc-upf ip link set upfgtp up 2>/dev/null || true
            
            # Verificar novamente
            UPFGTP_IPV4=$(docker compose exec -T free5gc-upf ip addr show upfgtp | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1)
            
            if [ -n "$UPFGTP_IPV4" ]; then
                echo -e "${GREEN}✅ IPv4 atribuído com sucesso: $UPFGTP_IPV4${NC}"
            else
                echo -e "${RED}❌ Falha ao atribuir IPv4 à interface upfgtp${NC}"
            fi
        else
            echo -e "${RED}❌ Não foi possível obter o IP do container${NC}"
        fi
    else
        echo -e "${GREEN}✅ Interface upfgtp tem IPv4: $UPFGTP_IPV4${NC}"
    fi
else
    echo -e "${RED}❌ Interface upfgtp não encontrada${NC}"
    echo "   Isso indica que o módulo gtp5g não está funcionando corretamente"
    echo "   Verifique se o módulo está carregado no host: lsmod | grep gtp5g"
fi

echo ""
echo "✅ Verificação do UPF concluída!"
echo ""

