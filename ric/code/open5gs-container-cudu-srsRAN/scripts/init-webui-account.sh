#!/bin/bash

# Script para criar a conta padrão de acesso ao WebUI do Open5GS
# A imagem gradiant/open5gs-webui não cria a conta admin automaticamente,
# diferente da instalação baremetal do Open5GS.
#
# Conta padrão criada:
#   Usuário: admin
#   Senha:   1423
#
# Autor: Jonas Augusto Kunzler

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Credenciais padrão
WEBUI_USER="admin"
WEBUI_PASS="1423"

# Salt/hash oficiais do Open5GS para a conta admin/1423
# (pbkdf2 via passport-local-mongoose, valores publicados pelo mantenedor)
SALT="f5c15fa72622d62b6b790aa8569b9339729801ab8bda5d13997b5db6bfc1d997"
HASH="402223057db5194899d2e082aeb0802f6794622e1cbc47529c419e5a603f2cc592074b4f3323b239ffa594c8b756d5c70a4e1f6ecd3f9f0d2d7328c4cf8b1b766514effff0350a90b89e21eac54cd4497a169c0c7554a0e2cd9b672e5414c323f76b8559bc768cba11cad2ea3ae704fb36abc8abc2619231ff84ded60063c6e1554a9777a4a464ef9cfdfa90ecfdacc9844e0e3b2f91b59d9ff024aec4ea1f51b703a31cda9afb1cc2c719a09cee4f9852ba3cf9f07159b1ccf8133924f74df770b1a391c19e8d67ffdcbbef4084a3277e93f55ac60d80338172b2a7b3f29cfe8a36738681794f7ccbe9bc98f8cdeded02f8a4cd0d4b54e1d6ba3d11792ee0ae8801213691848e9c5338e39485816bb0f734b775ac89f454ef90992003511aa8cceed58a3ac2c3814f14afaaed39cbaf4e2719d7213f81665564eec02f60ede838212555873ef742f6666cc66883dcb8281715d5c762fb236d72b770257e7e8d86c122bb69028a34cf1ed93bb973b440fa89a23604cd3fefe85fbd7f55c9b71acf6ad167228c79513f5cfe899a2e2cc498feb6d2d2f07354a17ba74cecfbda3e87d57b147e17dcc7f4c52b802a8e77f28d255a6712dcdc1519e6ac9ec593270bfcf4c395e2531a271a841b1adefb8516a07136b0de47c7fd534601b16f0f7a98f1dbd31795feb97da59e1d23c08461cf37d6f2877d0f2e437f07e25015960f63"

echo "=========================================="
echo "Criar conta de acesso ao WebUI (Open5GS)"
echo "=========================================="
echo ""

# Verificar se MongoDB está rodando
if ! docker compose ps mongodb | grep -q "Up"; then
    echo -e "${RED}❌ MongoDB não está rodando${NC}"
    echo "Execute: docker compose up -d mongodb"
    exit 1
fi

# Verificar se a conta admin já existe
EXISTS=$(docker compose exec -T mongodb mongosh open5gs --quiet --eval "db.accounts.countDocuments({username: '$WEBUI_USER'})" 2>/dev/null | tr -d '\n' || echo "0")

if [ "$EXISTS" != "0" ]; then
    echo -e "${GREEN}✅ Conta '$WEBUI_USER' já existe. Nada a fazer.${NC}"
    exit 0
fi

echo -e "${YELLOW}Criando conta padrão do WebUI...${NC}"
docker compose exec -T mongodb mongosh open5gs --quiet --eval "
db.accounts.insertOne({
    salt: '$SALT',
    hash: '$HASH',
    username: '$WEBUI_USER',
    roles: ['admin'],
    __v: 0
})
" >/dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Conta criada com sucesso!${NC}"
    echo ""
    echo "  WebUI:   http://localhost:9999"
    echo "  Usuário: $WEBUI_USER"
    echo "  Senha:   $WEBUI_PASS"
    echo ""
    echo -e "${YELLOW}💡 Recomenda-se trocar a senha após o primeiro login (menu Account).${NC}"
else
    echo -e "${RED}❌ Erro ao criar a conta do WebUI${NC}"
    exit 1
fi
