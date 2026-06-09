#!/bin/bash

# Script para adicionar usuário admin do WebUI (admin/1423) ao MongoDB
# Use quando o initdb.d não rodou (ex.: volume já existia)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

MONGO_CONTAINER=""
if docker ps --format '{{.Names}}' | grep -q "open5gs-mongodb-containerized"; then
  MONGO_CONTAINER="open5gs-mongodb-containerized"
elif docker ps --format '{{.Names}}' | grep -qE ".*mongodb.*"; then
  MONGO_CONTAINER=$(docker ps --format '{{.Names}}' | grep -E ".*mongodb.*" | head -1)
fi

if [ -z "$MONGO_CONTAINER" ]; then
  echo -e "${RED}❌ Container MongoDB não encontrado${NC}"
  echo "Execute: ./scripts/up_core.sh"
  exit 1
fi

echo "=========================================="
echo "Adicionar Admin do WebUI (admin/1423)"
echo "=========================================="
echo ""
echo "Container: $MONGO_CONTAINER"
echo ""

EXISTS=$(docker exec "$MONGO_CONTAINER" mongosh open5gs --quiet --eval "db.accounts.countDocuments({username: 'admin'})" 2>/dev/null | tr -d '\n\r' || echo "0")

if [ "$EXISTS" != "0" ]; then
  echo -e "${GREEN}✅ Usuário admin já existe no MongoDB${NC}"
  echo "   Login: admin / 1423"
  exit 0
fi

echo -e "${YELLOW}Criando usuário admin...${NC}"
docker exec -i "$MONGO_CONTAINER" mongosh open5gs --quiet <<'EOF'
db.accounts.insertOne({
  salt: 'f5c15fa72622d62b6b790aa8569b9339729801ab8bda5d13997b5db6bfc1d997',
  hash: '402223057db5194899d2e082aeb0802f6794622e1cbc47529c419e5a603f2cc592074b4f3323b239ffa594c8b756d5c70a4e1f6ecd3f9f0d2d7328c4cf8b1b766514effff0350a90b89e21eac54cd4497a169c0c7554a0e2cd9b672e5414c323f76b8559bc768cba11cad2ea3ae704fb36abc8abc2619231ff84ded60063c6e1554a9777a4a464ef9cfdfa90ecfdacc9844e0e3b2f91b59d9ff024aec4ea1f51b703a31cda9afb1cc2c719a09cee4f9852ba3cf9f07159b1ccf8133924f74df770b1a391c19e8d67ffdcbbef4084a3277e93f55ac60d80338172b2a7b3f29cfe8a36738681794f7ccbe9bc98f8cdeded02f8a4cd0d4b54e1d6ba3d11792ee0ae8801213691848e9c5338e39485816bb0f734b775ac89f454ef90992003511aa8cceed58a3ac2c3814f14afaaed39cbaf4e2719d7213f81665564eec02f60ede838212555873ef742f6666cc66883dcb8281715d5c762fb236d72b770257e7e8d86c122bb69028a34cf1ed93bb973b440fa89a23604cd3fefe85fbd7f55c9b71acf6ad167228c79513f5cfe899a2e2cc498feb6d2d2f07354a17ba74cecfbda3e87d57b147e17dcc7f4c52b802a8e77f28d255a6712dcdc1519e6ac9ec593270bfcf4c395e2531a271a841b1adefb8516a07136b0de47c7fd534601b16f0f7a98f1dbd31795feb97da59e1d23c08461cf37d6f2877d0f2e437f07e25015960f63',
  username: 'admin',
  roles: ['admin'],
  __v: 0
});
EOF

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Admin criado com sucesso!${NC}"
  echo ""
  echo "   URL:  http://localhost:9999"
  echo "   Login: admin / 1423"
else
  echo -e "${RED}❌ Erro ao criar admin${NC}"
  exit 1
fi
