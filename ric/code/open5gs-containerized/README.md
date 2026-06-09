# Laboratório Open5GS Containerizado

Laboratório 5G totalmente containerizado usando Open5GS com suporte a múltiplas UPFs e testes fim-a-fim com UERANSIM.

O projeto utiliza **dois docker-compose**:

- **Core (SBI)**: `docker-compose.yml` na raiz — NFs do control plane, UPF-A/UPF-B, MongoDB, DN, WebUI
- **RAN (gNB + UE)**: `ueransim/docker-compose.yaml` — UERANSIM

## Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- Ubuntu 22.04+ (recomendado)
- ~4GB RAM livre
- Acesso à internet (para pull de imagens)

## Arquitetura

| Compose | Arquivo | Serviços |
|---------|---------|----------|
| **Core** | `docker-compose.yml` | MongoDB, NRF, SCP, AMF, SMF, AUSF, UDM, UDR, PCF, NSSF, UPF-A, UPF-B, DN, WebUI |
| **RAN** | `ueransim/docker-compose.yaml` | UERANSIM (gNB + UE) |

O compose RAN usa as redes externas `open5gs-containerized_net-n2` e `open5gs-containerized_net-n3` criadas pelo Core. **Inicie o Core primeiro.**

### Redes Docker

- **net-sbi** (10.10.0.0/16): SBI entre NFs
- **net-n2** (10.20.0.0/16): NGAP entre AMF e gNB
- **net-n3** (10.30.0.0/16): GTP-U entre gNB e UPF
- **net-n4** (10.40.0.0/16): PFCP entre SMF e UPF
- **net-n6** (10.50.0.0/16): Data Network
- **ue-subnet** (10.60.0.0/16): IPs dos UEs

## Início Rápido

```bash
cd ric/code/open5gs-containerized

# 1. Subir o Core
./scripts/up_core.sh

# 2. Adicionar subscriber (IMSI alinhado ao ue.yaml)
./scripts/add-subscriber.sh

# 3. Subir o RAN (gNB + UE)
./scripts/up_ran.sh

# 4. Verificar saúde
./scripts/healthcheck.sh

# 5. Teste E2E
./scripts/test_ue_connection.sh
```

### WebUI

- **URL:** http://localhost:9999
- **Login:** `admin` / `1423`

Se o login falhar (volume MongoDB já existia), execute:

```bash
./scripts/add-webui-admin.sh
```

### Parar o laboratório

```bash
./scripts/down_ran.sh
./scripts/down_core.sh
```

## Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `up_core.sh` | Inicia o Core Open5GS |
| `up_ran.sh` | Inicia gNB + UE (após o Core) |
| `down_core.sh` / `down_ran.sh` | Para Core ou RAN |
| `up.sh` / `down.sh` | Sobe/para apenas o Core |
| `healthcheck.sh` | Verifica saúde dos serviços |
| `test_ue_connection.sh` | Teste E2E do UE |
| `test-system-status.sh` | Diagnóstico detalhado |
| `add-subscriber.sh` | Insere UE no MongoDB |
| `add-webui-admin.sh` | Cria admin do WebUI |

## Troubleshooting

| Sintoma | Ação |
|---------|------|
| Rede `open5gs-containerized_net-n2` não encontrada | Execute `./scripts/up_core.sh` primeiro |
| Registration rejected | `./scripts/add-subscriber.sh` |
| PDU session falhou | Verifique logs SMF/UPF: `docker compose logs smf upf-a` |
| Sem IP no UE | `docker restart ueransim` após adicionar subscriber |
| AMF context not found | Use UERANSIM 3.2.6 (já configurado) |

## Variáveis de Ambiente

Copie `.env.example` para `.env` se necessário:

```bash
OPEN5GS_IMAGE=gradiant/open5gs:2.7.6
MONGODB_IMAGE=mongo:7.0
UERANSIM_IMAGE=gradiant/ueransim:3.2.6
DN_IMAGE=alpine:latest
```

## Documentação Adicional

- `docs/labs/INDICE.md` — Roteiros de laboratório
- `ueransim/docs/RAN.md` — Documentação da RAN
