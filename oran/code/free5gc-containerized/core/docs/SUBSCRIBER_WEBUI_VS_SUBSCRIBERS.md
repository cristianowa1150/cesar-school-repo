# Por que existem `subscribers` e a lista da WebUI?

## Resumo

| Origem | Coleções MongoDB típicas | Aparece na WebUI? |
|--------|----------------------------|-------------------|
| **`add-subscriber.sh` (parte MongoDB)** | `free5gc.subscribers` (formato legado / testes) | **Não** — a WebUI não usa esta coleção para a lista. |
| **`add-subscriber.sh` (parte API)** ou **WebUI “CREATE”** | `subscriptionData.provisionedData.amData`, `subscriptionData.authenticationData.webAuthenticationSubscription`, `subscriptionData.identityData`, etc. | **Sim** |

O backend da WebConsole ([`api_webui.go`](https://github.com/free5gc/webconsole/blob/main/backend/WebUI/api_webui.go)) monta a lista em `GetSubscribers` a partir de **`subscriptionData.provisionedData.amData`** (`amDataColl`), não de `db.subscribers`.

O script **`./scripts/add-subscriber.sh`** faz **as duas coisas** por padrão: POST na API (como “CREATE” no console) e insert em `free5gc.subscribers`. Para **só** MongoDB: `SKIP_WEBUI=1 ./scripts/add-subscriber.sh`.

## O que usar

- **Fluxo normal (aula):** `./scripts/add-subscriber.sh` — WebUI + `subscribers` alinhados ao mesmo SUPI/MSISDN no topo do script.
- **Sem a WebUI em execução:** `SKIP_WEBUI=1 ./scripts/add-subscriber.sh` — apenas `db.subscribers` (a lista SUBSCRIBERS no console não terá esse IMSI).

Referência oficial: [Create Subscriber via webconsole](https://free5gc.org/guide/Webconsole/Create-Subscriber-via-webconsole/) e issue [free5gc#539](https://github.com/free5gc/free5gc/issues/539) (POST `/api/subscriber/...`).
