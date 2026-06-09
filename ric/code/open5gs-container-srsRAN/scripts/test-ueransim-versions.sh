#!/bin/bash

# Script para testar diferentes versões do UERANSIM
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-15
#
# Este script testa diferentes versões do UERANSIM para identificar
# qual versão resolve o problema de "AMF context not found"

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Diretório do projeto
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Versões do UERANSIM para testar (ordenadas da mais recente para mais antiga)
# Nota: Apenas versões que realmente existem no Docker Hub
VERSIONS=(
    "3.2.7"  # Versão atual (com problema)
    "3.2.6"  # Corrige vazamentos de memória no gNB ✅ Disponível
    "3.2.4"  # Melhorias em sessões PDU, Initial Context Setup ✅ Disponível
    "3.2.2"  # Versão intermediária ✅ Disponível
    "3.1.6"  # Versão estável ✅ Disponível
    "3.1.0"  # Versão estável ✅ Disponível
)

# Função para exibir ajuda
show_help() {
    cat << EOF
Uso: $0 [OPÇÕES]

Testa diferentes versões do UERANSIM para identificar qual resolve o problema
de "AMF context not found" e permite conexão E2E completa.

OPÇÕES:
    -v, --version VERSION    Testa apenas uma versão específica (ex: 3.2.6)
    -l, --list               Lista versões disponíveis e sai
    -a, --all                Testa todas as versões (padrão)
    -s, --stop               Para todos os containers e sai
    -c, --clean              Limpa containers e redes antes de testar
    -t, --timeout SECONDS    Timeout para cada teste (padrão: 120)
    -h, --help               Mostra esta ajuda

EXEMPLOS:
    $0                      # Testa todas as versões
    $0 -v 3.2.6            # Testa apenas v3.2.6
    $0 -l                  # Lista versões disponíveis
    $0 -s                  # Para tudo e sai
    $0 -c -v 3.2.6         # Limpa e testa v3.2.6

NOTAS:
    - Cada teste reinicia os containers com a versão especificada
    - Os logs são salvos em logs/ueransim-versions/
    - O script verifica se o problema "AMF context not found" foi resolvido
EOF
}

# Função para listar versões
list_versions() {
    echo "Versões do UERANSIM disponíveis para teste:"
    echo ""
    for i in "${!VERSIONS[@]}"; do
        version="${VERSIONS[$i]}"
        if [ "$version" = "3.2.7" ]; then
            echo -e "  ${i}. ${YELLOW}v${version}${NC} (atual - com problema conhecido)"
        elif [ "$version" = "3.2.6" ]; then
            echo -e "  ${i}. ${GREEN}v${version}${NC} (corrige vazamentos de memória)"
        elif [ "$version" = "3.2.4" ]; then
            echo -e "  ${i}. ${GREEN}v${version}${NC} (melhorias em sessões PDU) ✅ Disponível"
        elif [ "$version" = "3.2.2" ]; then
            echo -e "  ${i}. v${version} ✅ Disponível"
        elif [ "$version" = "3.1.6" ]; then
            echo -e "  ${i}. v${version} (versão estável) ✅ Disponível"
        elif [ "$version" = "3.1.0" ]; then
            echo -e "  ${i}. v${version} (versão estável) ✅ Disponível"
        else
            echo -e "  ${i}. v${version}"
        fi
    done
    echo ""
}

# Função para parar containers
stop_containers() {
    echo -e "${YELLOW}Parando containers...${NC}"
    docker compose down 2>/dev/null || true
    echo -e "${GREEN}✅ Containers parados${NC}"
}

# Função para limpar ambiente
clean_environment() {
    echo -e "${YELLOW}Limpando ambiente...${NC}"
    docker compose down -v 2>/dev/null || true
    docker network prune -f 2>/dev/null || true
    echo -e "${GREEN}✅ Ambiente limpo${NC}"
}

# Função para testar uma versão
test_version() {
    local version=$1
    local timeout=${2:-120}
    local log_dir="$PROJECT_DIR/logs/ueransim-versions"
    mkdir -p "$log_dir"
    
    echo ""
    echo "=========================================="
    echo -e "${BLUE}Testando UERANSIM ${version}${NC}"
    echo "=========================================="
    
    # Atualizar docker-compose.yml com a versão
    echo -e "${YELLOW}Configurando versão ${version}...${NC}"
    
    # Tentar diferentes formatos de tag (com e sem "v")
    local image_tag=""
    local image_found=false
    
    # Primeiro, tentar sem "v" (formato padrão do Docker Hub)
    if docker image inspect "gradiant/ueransim:${version}" >/dev/null 2>&1; then
        image_tag="${version}"
        image_found=true
        echo -e "${GREEN}✅ Imagem encontrada localmente: gradiant/ueransim:${version}${NC}"
    else
        echo -e "${YELLOW}Imagem não encontrada localmente. Tentando baixar gradiant/ueransim:${version}...${NC}"
        if docker pull "gradiant/ueransim:${version}" >/dev/null 2>&1; then
            image_tag="${version}"
            image_found=true
            echo -e "${GREEN}✅ Imagem baixada com sucesso: gradiant/ueransim:${version}${NC}"
        else
            # Se falhar, tentar com "v"
            echo -e "${YELLOW}Tentando com prefixo 'v': gradiant/ueransim:v${version}...${NC}"
            if docker image inspect "gradiant/ueransim:v${version}" >/dev/null 2>&1; then
                image_tag="v${version}"
                image_found=true
                echo -e "${GREEN}✅ Imagem encontrada localmente: gradiant/ueransim:v${version}${NC}"
            elif docker pull "gradiant/ueransim:v${version}" >/dev/null 2>&1; then
                image_tag="v${version}"
                image_found=true
                echo -e "${GREEN}✅ Imagem baixada com sucesso: gradiant/ueransim:v${version}${NC}"
            fi
        fi
    fi
    
    if [ "$image_found" = false ]; then
        echo -e "${RED}❌ Erro: Imagem gradiant/ueransim:${version} ou gradiant/ueransim:v${version} não encontrada${NC}"
        echo -e "${YELLOW}Verificando tags disponíveis...${NC}"
        curl -s "https://hub.docker.com/v2/repositories/gradiant/ueransim/tags?page_size=20" | \
            python3 -c "import sys, json; data = json.load(sys.stdin); tags = [r['name'] for r in data.get('results', []) if '3.2' in r['name'] or '3.1' in r['name']]; print('Tags disponíveis:', ', '.join(sorted(tags)[:10]))" 2>/dev/null || \
            echo "Não foi possível verificar tags disponíveis"
        return 1
    fi
    
    export UERANSIM_IMAGE="gradiant/ueransim:${image_tag}"
    
    # Parar containers anteriores
    stop_containers
    
    # Iniciar containers
    echo -e "${YELLOW}Iniciando containers com ${image_tag}...${NC}"
    UERANSIM_IMAGE="gradiant/ueransim:${image_tag}" docker compose up -d
    
    # Aguardar serviços iniciarem
    echo -e "${YELLOW}Aguardando serviços iniciarem (30s)...${NC}"
    sleep 30
    
    # Aguardar mais tempo para estabilização
    echo -e "${YELLOW}Aguardando estabilização (${timeout}s)...${NC}"
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        sleep 10
        elapsed=$((elapsed + 10))
        echo -n "."
    done
    echo ""
    
    # Verificar logs
    echo -e "${YELLOW}Verificando logs...${NC}"
    
    # Salvar logs
    local log_file="$log_dir/ueransim-${image_tag}-$(date +%Y%m%d-%H%M%S).log"
    {
        echo "=== Logs do gNB ==="
        docker compose logs ueransim-gnb --tail 100
        echo ""
        echo "=== Logs do UE ==="
        docker compose logs ueransim-ue --tail 100
        echo ""
        echo "=== Logs do AMF ==="
        docker compose logs amf --tail 50
    } > "$log_file"
    
    # Verificar problemas conhecidos (tr -d '\n' remove quebras de linha)
    local amf_context_errors=$(docker compose logs ueransim-gnb 2>&1 | grep -c "AMF context not found" 2>/dev/null | tr -d '\n' || echo "0")
    local ng_setup_success=$(docker compose logs ueransim-gnb 2>&1 | grep -c "NG Setup.*successful\|NG Setup.*succeeded\|NG Setup procedure is successful" 2>/dev/null | tr -d '\n' || echo "0")
    local ue_registered=$(docker compose logs ueransim-ue 2>&1 | grep -c "MM-REGISTERED" 2>/dev/null | tr -d '\n' || echo "0")
    local ue_cell_found=$(docker compose logs ueransim-ue 2>&1 | grep -c "Selected cell\|signal detected" 2>/dev/null | tr -d '\n' || echo "0")
    local ue_registration_failed=$(docker compose logs ueransim-ue 2>&1 | grep -c "Registration failed\|FIVEG_SERVICES_NOT_ALLOWED" 2>/dev/null | tr -d '\n' || echo "0")
    local ue_ip=$(docker compose exec -T ueransim-ue ip addr show 2>/dev/null | grep -oP 'inet \K10\.60\.\d+\.\d+' | head -1 || echo "")
    
    # Resultado
    echo ""
    echo "=========================================="
    echo -e "${BLUE}Resultado do Teste - ${image_tag}${NC}"
    echo "=========================================="
    echo "NG Setup bem-sucedido: $ng_setup_success vez(es)"
    echo "Erros 'AMF context not found': $amf_context_errors"
    echo "Erros de registro do UE: $ue_registration_failed vez(es)"
    echo "UE encontrou células: $ue_cell_found vez(es)"
    echo "UE registrado (MM-REGISTERED): $ue_registered vez(es)"
    if [ -n "$ue_ip" ]; then
        echo "IP do UE: $ue_ip"
    else
        echo "IP do UE: não atribuído"
    fi
    echo ""
    
    # Avaliar resultado
    local success=false
    if [ "$amf_context_errors" -eq 0 ] && [ "$ng_setup_success" -gt 0 ] && [ "$ue_registered" -gt 0 ]; then
        echo -e "${GREEN}✅ SUCESSO! ${image_tag} resolve o problema!${NC}"
        success=true
    elif [ "$amf_context_errors" -eq 0 ] && [ "$ng_setup_success" -gt 0 ] && [ "$ue_registration_failed" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  NG Setup OK, mas registro do UE falhou ($ue_registration_failed vez(es))${NC}"
        echo -e "${YELLOW}   Verifique se o subscriber está no MongoDB: ./scripts/add-subscriber.sh${NC}"
    elif [ "$amf_context_errors" -eq 0 ] && [ "$ng_setup_success" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Parcial: NG Setup OK, mas UE não registrou${NC}"
    elif [ "$amf_context_errors" -gt 0 ]; then
        echo -e "${RED}❌ Problema persiste: AMF context not found ($amf_context_errors ocorrências)${NC}"
    else
        echo -e "${RED}❌ NG Setup não foi bem-sucedido${NC}"
    fi
    
    echo "Logs salvos em: $log_file"
    echo ""
    
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}

# Parse de argumentos
TEST_VERSION=""
LIST_ONLY=false
TEST_ALL=true
STOP_ONLY=false
CLEAN=false
TIMEOUT=120

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            TEST_VERSION="$2"
            TEST_ALL=false
            shift 2
            ;;
        -l|--list)
            LIST_ONLY=true
            shift
            ;;
        -a|--all)
            TEST_ALL=true
            shift
            ;;
        -s|--stop)
            STOP_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo -e "${RED}Erro: Opção desconhecida: $1${NC}"
            show_help
            exit 1
            ;;
    esac
done

# Executar ações
if [ "$LIST_ONLY" = true ]; then
    list_versions
    exit 0
fi

if [ "$STOP_ONLY" = true ]; then
    stop_containers
    exit 0
fi

if [ "$CLEAN" = true ]; then
    clean_environment
fi

# Testar versões
if [ -n "$TEST_VERSION" ]; then
    # Testar versão específica
    if [[ " ${VERSIONS[@]} " =~ " ${TEST_VERSION} " ]]; then
        test_version "$TEST_VERSION" "$TIMEOUT"
    else
        echo -e "${RED}Erro: Versão $TEST_VERSION não está na lista de versões disponíveis${NC}"
        list_versions
        exit 1
    fi
elif [ "$TEST_ALL" = true ]; then
    # Testar todas as versões
    echo "=========================================="
    echo "Teste de Versões do UERANSIM"
    echo "=========================================="
    echo ""
    echo "Este script testará as seguintes versões:"
    list_versions
    echo ""
    read -p "Deseja continuar? (s/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Cancelado."
        exit 0
    fi
    
    success_versions=()
    failed_versions=()
    
    for version in "${VERSIONS[@]}"; do
        if test_version "$version" "$TIMEOUT"; then
            success_versions+=("$version")
            echo -e "${GREEN}✅ v${version} funcionou!${NC}"
            echo ""
            read -p "Deseja continuar testando outras versões? (s/N): " -n 1 -r
            echo ""
            if [[ ! $REPLY =~ ^[Ss]$ ]]; then
                break
            fi
        else
            failed_versions+=("$version")
        fi
    done
    
    # Resumo final
    echo ""
    echo "=========================================="
    echo "Resumo dos Testes"
    echo "=========================================="
    if [ ${#success_versions[@]} -gt 0 ]; then
        echo -e "${GREEN}Versões que funcionaram:${NC}"
        for v in "${success_versions[@]}"; do
            echo -e "  ✅ v${v}"
        done
    fi
    if [ ${#failed_versions[@]} -gt 0 ]; then
        echo -e "${RED}Versões que falharam:${NC}"
        for v in "${failed_versions[@]}"; do
            echo -e "  ❌ v${v}"
        done
    fi
    echo ""
fi

