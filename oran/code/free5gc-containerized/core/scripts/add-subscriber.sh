#!/bin/bash
#
# Cria o mesmo subscriber em dois locais:
#   1) UDR via API da WebConsole (POST /api/subscriber/...) — aparece na lista SUBSCRIBERS da WebUI.
#   2) Coleção MongoDB free5gc.subscribers — formato usado em vários labs e scripts.
#
# Variáveis no topo (SUPI, K, OP, …) são aplicadas ao JSON WebUI com jq (sem duplicar IMSI à mão).
# MSISDN: por padrão 0 + últimos 9 dígitos do IMSI (ex. ...000003 → 0900000003), para evitar
# "duplicate gpsi" no UDR. Sobrescrever: MSISDN=0900000999 ./scripts/add-subscriber.sh
# Para só popular MongoDB (sem WebUI): SKIP_WEBUI=1 ./scripts/add-subscriber.sh
#
# Ver: docs/SUBSCRIBER_WEBUI_VS_SUBSCRIBERS.md
#
# Autor: Jonas Augusto Kunzler
# Data: 2026-01-20

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

SKIP_WEBUI="${SKIP_WEBUI:-0}"
WEBUI_URL="${WEBUI_URL:-http://127.0.0.1:5000}"
WEBUI_USER="${WEBUI_USER:-admin}"
WEBUI_PASS="${WEBUI_PASS:-free5gc}"
PAYLOAD_TEMPLATE="${ADD_SUBSCRIBER_JSON:-$SCRIPT_DIR/data/subscriber-webui-payload.json}"

TMP_PAYLOAD=""

cleanup() {
    [ -n "$TMP_PAYLOAD" ] && rm -f "$TMP_PAYLOAD"
}
trap cleanup EXIT

# mongo:4.4 traz o shell legado "mongo"; imagens mais novas podem usar "mongosh".
mongo_cli() {
    if docker compose exec -T db sh -c 'command -v mongosh >/dev/null 2>&1'; then
        docker compose exec -T db mongosh "$@"
    else
        docker compose exec -T db mongo "$@"
    fi
}

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "Adicionar Subscriber ao free5GC"
echo "=========================================="
echo ""

if ! docker compose ps db | grep -q "Up"; then
    echo -e "${RED}❌ MongoDB não está rodando${NC}"
    echo "Execute: docker compose up -d db"
    exit 1
fi

# Dados do subscriber (alinhar com config/ue_srsue.conf e docs/CONECTAR_UE.md)
SUPI="imsi-208930000000001"
MCC="208"
MNC="93"
PLMN_ID="${MCC}${MNC}"
IMSI_NUM="${SUPI#imsi-}"
MSISDN="${MSISDN:-0${IMSI_NUM: -9}}"
K="8baf473f2f8fd09487cccbd7097c6862"
OP="8e27b6af0e692e750f32667a3b14605d"
OPC="8e27b6af0e692e750f32667a3b14605d"
AMF="8000"

echo -e "${YELLOW}Subscriber:${NC}"
echo "  SUPI: $SUPI"
echo "  MSISDN: $MSISDN"
echo "  PLMN: $PLMN_ID (MCC $MCC, MNC $MNC)"
echo ""

# --- 1) WebUI / UDR ---
if [ "$SKIP_WEBUI" != "1" ]; then
    if ! command -v curl >/dev/null 2>&1; then
        echo -e "${RED}❌ curl não encontrado (necessário para a API WebUI).${NC}"
        exit 1
    fi
    if ! command -v jq >/dev/null 2>&1; then
        echo -e "${RED}❌ jq não encontrado — use para alinhar o payload ao SUPI/MSISDN, ou SKIP_WEBUI=1.${NC}"
        exit 1
    fi
    if [ ! -f "$PAYLOAD_TEMPLATE" ]; then
        echo -e "${RED}❌ JSON não encontrado: $PAYLOAD_TEMPLATE${NC}"
        exit 1
    fi

    TMP_PAYLOAD=$(mktemp)
    jq \
        --arg ue "$SUPI" \
        --arg plmn "$PLMN_ID" \
        --arg gpsi "msisdn-$MSISDN" \
        --arg k "$K" \
        --arg op "$OP" \
        --arg opc "$OPC" \
        --arg amf "$AMF" \
        '.ueId = $ue
        | .plmnID = $plmn
        | .AccessAndMobilitySubscriptionData.gpsis = [$gpsi]
        | .AuthenticationSubscription.permanentKey.permanentKeyValue = $k
        | .AuthenticationSubscription.milenage.op.opValue = $op
        | .AuthenticationSubscription.opc.opcValue = $opc
        | .AuthenticationSubscription.authenticationManagementField = $amf' \
        "$PAYLOAD_TEMPLATE" >"$TMP_PAYLOAD"

    echo -e "${YELLOW}Registro no UDR (WebConsole API)...${NC}"
    LOGIN_OK=0
    for attempt in 1 2 3 4 5; do
        LOGIN_RESP=$(curl -sS -m 15 -X POST "$WEBUI_URL/api/login" \
            -H "Content-Type: application/json" \
            -d "{\"username\":\"$WEBUI_USER\",\"password\":\"$WEBUI_PASS\"}" 2>/dev/null) || LOGIN_RESP=""
        if echo "$LOGIN_RESP" | grep -q '"access_token"'; then
            LOGIN_OK=1
            break
        fi
        if [ "$attempt" -lt 5 ]; then
            echo "   WebUI ainda não respondeu... ($attempt/5)"
            sleep 3
        fi
    done
    if [ "$LOGIN_OK" != "1" ]; then
        echo -e "${RED}❌ Falha no login WebUI ($WEBUI_URL).${NC}"
        echo "${LOGIN_RESP:-(sem resposta)}"
        exit 1
    fi
    TOKEN=$(echo "$LOGIN_RESP" | jq -r '.access_token')
    if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
        echo -e "${RED}❌ access_token inválido.${NC}"
        exit 1
    fi

    API_PATH="/api/subscriber/${SUPI}/${PLMN_ID}"
    HTTP_CODE=$(curl -sS -o /tmp/webui-post-body.txt -w "%{http_code}" -X POST "$WEBUI_URL$API_PATH" \
        -H "Content-Type: application/json" \
        -H "Token: $TOKEN" \
        --data-binary @"$TMP_PAYLOAD")

    if [ "$HTTP_CODE" = "201" ] || [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ UDR / WebUI: OK (HTTP $HTTP_CODE). Atualize SUBSCRIBERS na console.${NC}"
    elif [ "$HTTP_CODE" = "409" ]; then
        echo -e "${YELLOW}⚠️  HTTP 409 — já existe no UDR; o registro existente é mantido.${NC}"
    elif [ "$HTTP_CODE" = "400" ] && grep -q 'duplicate gpsi' /tmp/webui-post-body.txt 2>/dev/null; then
        echo -e "${RED}❌ duplicate gpsi: este MSISDN já está associado a outro UE no UDR.${NC}"
        echo "   Remova o subscriber antigo na WebUI ou use um MSISDN alinhado ao IMSI (por padrão: 0 + últimos 9 dígitos do IMSI)."
        cat /tmp/webui-post-body.txt 2>/dev/null || true
        exit 1
    else
        echo -e "${RED}❌ Erro WebUI HTTP $HTTP_CODE${NC}"
        cat /tmp/webui-post-body.txt 2>/dev/null || true
        exit 1
    fi
    echo ""
else
    echo -e "${YELLOW}SKIP_WEBUI=1 — ignorando a API WebUI (só MongoDB).${NC}"
    echo ""
fi

# --- 2) free5gc.subscribers ---
echo "Verificando se subscriber já existe em free5gc.subscribers..."
EXISTS=$(mongo_cli free5gc --quiet --eval "db.subscribers.countDocuments({supi: '$SUPI'})" 2>/dev/null | tr -d '\n\r ' || echo "0")

if [ "$EXISTS" != "0" ] && [ "$EXISTS" != "" ]; then
    echo -e "${YELLOW}⚠️  Subscriber já existe. Removendo...${NC}"
    mongo_cli free5gc --quiet --eval "db.subscribers.deleteOne({supi: '$SUPI'})" >/dev/null 2>&1
    sleep 1
fi

echo -e "${YELLOW}Inserindo em free5gc.subscribers...${NC}"
set +e
INSERT_ERR=$(mongo_cli free5gc --quiet --eval "
db.subscribers.insertOne({
    supi: '$SUPI',
    plmnId: {
        mcc: '$MCC',
        mnc: '$MNC'
    },
    gpsis: ['msisdn-$MSISDN'],
    nssai: [
        {
            sst: 1,
            sd: '010203'
        },
        {
            sst: 1,
            sd: '112233'
        }
    ],
    authenticationSubscription: {
        authenticationMethod: '5G_AKA',
        permanentKey: {
            permanentKeyValue: '$K'
        },
        opc: {
            opcValue: '$OPC'
        },
        op: {
            opValue: '$OP'
        },
        authenticationManagementField: '$AMF',
        sequenceNumber: {
            sqnScheme: 'NON_TIME_BASED',
            sqn: '000000000000',
            lastIndexes: {
                ausf: 0
            }
        },
        encOpcKey: {
            encOpcKeyValue: '$OPC'
        },
        encPermanentKey: {
            encPermanentKeyValue: '$K'
        }
    },
    amPolicyData: {
        subscCats: ['free5gc']
    },
    smPolicyData: {
        smPolicySnssaiData: {
            '010203': {
                smPolicyDnnData: {
                    internet: {
                        dnn: 'internet'
                    }
                }
            },
            '112233': {
                smPolicyDnnData: {
                    internet: {
                        dnn: 'internet'
                    }
                }
            }
        }
    },
    smData: [
        {
            servingPlmnId: {
                mcc: '$MCC',
                mnc: '$MNC'
            },
            singleNssai: {
                sst: 1,
                sd: '010203'
            },
            dnnConfigurations: {
                internet: {
                    pduSessionTypes: {
                        defaultSessionType: 'IPV4',
                        allowedSessionTypes: ['IPV4']
                    },
                    sscModes: {
                        defaultSscMode: 'SSC_MODE_1',
                        allowedSscModes: ['SSC_MODE_1']
                    },
                    sessionAmbr: {
                        uplink: '1 Gbps',
                        downlink: '2 Gbps'
                    },
                    '5gQosProfile': {
                        '5qi': 9,
                        priorityLevel: 8
                    }
                }
            }
        },
        {
            servingPlmnId: {
                mcc: '$MCC',
                mnc: '$MNC'
            },
            singleNssai: {
                sst: 1,
                sd: '112233'
            },
            dnnConfigurations: {
                internet: {
                    pduSessionTypes: {
                        defaultSessionType: 'IPV4',
                        allowedSessionTypes: ['IPV4']
                    },
                    sscModes: {
                        defaultSscMode: 'SSC_MODE_1',
                        allowedSscModes: ['SSC_MODE_1']
                    },
                    sessionAmbr: {
                        uplink: '1 Gbps',
                        downlink: '2 Gbps'
                    },
                    '5gQosProfile': {
                        '5qi': 9,
                        priorityLevel: 8
                    }
                }
            }
        }
    ]
})
" 2>&1)
INSERT_RC=$?
set -e

if [ "$INSERT_RC" -eq 0 ]; then
    echo -e "${GREEN}✅ Documento inserido em free5gc.subscribers${NC}"
    echo ""
    echo "Verificação (coleção subscribers):"
    mongo_cli free5gc --quiet --eval "db.subscribers.findOne({supi: '$SUPI'}, {supi: 1, gpsis: 1, nssai: 1})" 2>/dev/null | head -10
    echo ""
    echo -e "${YELLOW}💡 Registro na rede: o UE deve autenticar com estes dados (ex.: ue_srsue.conf).${NC}"
else
    echo -e "${RED}❌ Erro ao adicionar subscriber no MongoDB${NC}"
    echo "$INSERT_ERR"
    echo ""
    echo "Diagnóstico rápido:"
    echo "  docker compose exec -T db sh -c 'command -v mongosh; command -v mongo'"
    echo "  docker compose logs db --tail 40"
    exit 1
fi
