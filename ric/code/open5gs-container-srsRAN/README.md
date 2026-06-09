# Laboratório Open5GS Containerizado

Laboratório 5G totalmente containerizado usando Open5GS com suporte a múltiplas UPFs para testes de failover.

## 📋 Índice

1. [Pré-requisitos](#pré-requisitos)
2. [Início Rápido](#início-rápido)
3. [Arquitetura](#arquitetura)
4. [Estrutura de Diretórios](#estrutura-de-diretórios)
5. [Scripts Disponíveis](#scripts-disponíveis)
6. [Testes](#testes)
7. [Adicionar Novas UPFs](#adicionar-novas-upfs)
8. [Troubleshooting](#troubleshooting)

---

## Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- Ubuntu 22.04+ (recomendado)
- ~4GB RAM livre
- Acesso à internet (para pull de imagens)

---

## Início Rápido

### 1. Clonar e entrar no diretório

```bash
cd modulo05-interfaces_protocolos_oran/code/open5gs-container
```

### 2. Iniciar o laboratório

```bash
./scripts/up.sh
```

### 3. Verificar status

```bash
./scripts/healthcheck.sh
```

### 4. Testar conexão do UE

```bash
./scripts/test_ue_connection.sh
```

### 5. Testar failover de UPF

```bash
./scripts/test_upf_failover.sh
```

### 6. Parar o laboratório

```bash
./scripts/down.sh
```

---

## Arquitetura

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   MongoDB   │     │     NRF      │     │     SCP     │
│   (UDR/PCF) │     │  (Discovery) │     │  (Routing)  │
└─────────────┘     └──────────────┘     └─────────────┘
       └───────────────────┴────────────────────┘
                           │
                    ┌──────┴──────────┐
                    │  SBI Network    │
                    │  (10.10.0.0/16) │
                    └──────┬──────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────┴────┐       ┌─────┴─────┐      ┌─────┴─────┐
   │   AMF   │       │    SMF    │      │  AUSF/UDM │
   │         │       │           │      │  UDR/PCF  │
   └────┬────┘       └─────┬─────┘      └───────────┘
        │                  │
        │ N2               │ N4
        │ (NGAP)           │ (PFCP)
        │                  │
   ┌────┴─────┐      ┌─────┴─────┐
   │   gNB    │      │  UPF-A    │
   │(UERANSIM)│      │  UPF-B    │
   └────┬─────┘      └─────┬─────┘
        │                  │
        │ N3               │ N6
        │ (GTP-U)          │ (Data)
        │                  │
   ┌────┴─────┐      ┌─────┴─────┐
   │   UE     │      │    DN     │
   │(UERANSIM)│      │ (Internet)│
   └──────────┘      └───────────┘
```

### Redes Docker

- **net-sbi** (10.10.0.0/16): Interface SBI entre NFs do control plane
- **net-n2** (10.20.0.0/16): Interface N2 (NGAP) entre AMF e gNB
- **net-n3** (10.30.0.0/16): Interface N3 (GTP-U) entre gNB e UPFs
- **net-n4** (10.40.0.0/16): Interface N4 (PFCP) entre SMF e UPFs
- **net-n6** (10.50.0.0/16): Interface N6 (Data) entre UPFs e DN
- **ue-subnet** (10.60.0.0/16): Subnet para IPs dos UEs

---

## Estrutura de Diretórios

```
open5gs-container-srsRAN/
├── configs/
│   ├── open5gs/          # Configurações Open5GS
│   │   ├── nrf.yaml
│   │   ├── amf.yaml
│   │   ├── smf.yaml
│   │   ├── upf-a.yaml    # UPF-A
│   │   ├── upf-b.yaml    # UPF-B
│   │   └── freeDiameter/
│   ├── ueransim/         # Configurações UERANSIM (gNB + UE)
│   │   ├── gnb.yaml
│   │   ├── ue.yaml
│   │   └── entrypoint.sh
│   └── srsRAN/           # Configurações srsRAN (alternativa ZMQ)
│       ├── gnb.yaml      # srsRAN Project gNB
│       └── ue.conf      # srsRAN 4G srsUE
├── scripts/
│   ├── up.sh                    # Iniciar laboratório
│   ├── down.sh                  # Parar laboratório
│   ├── add-subscriber.sh        # Provisionar subscriber no MongoDB
│   ├── apply-nat-host.sh        # NAT no host (UE → internet)
│   ├── troubleshoot.sh          # tcpdump, rotas, iptables
│   ├── healthcheck.sh           # Verificar saúde dos serviços
│   ├── test_ue_connection.sh   # Testar conexão do UE
│   └── test_upf_failover.sh    # Testar failover de UPF
├── logs/                        # Logs dos serviços
├── docs/                        # Documentação
├── docker-compose.yml           # Orquestração Docker
└── README.md                    # Este arquivo
```

---

## Scripts Disponíveis

### `up.sh`
Inicia todos os serviços do laboratório.

```bash
./scripts/up.sh
```

### `down.sh`
Para todos os serviços e remove containers/redes.

```bash
./scripts/down.sh
```

### `healthcheck.sh`
Verifica o status de todos os serviços e conectividade de rede.

```bash
./scripts/healthcheck.sh
```

### `test_ue_connection.sh`
Testa a conexão end-to-end do UE:
- Verifica IP do UE
- Testa ping para servidores DNS públicos
- Testa resolução DNS
- Testa acesso HTTP
- Verifica rota padrão
- Verifica conectividade com UPFs
- Verifica sessão PDU

```bash
./scripts/test_ue_connection.sh
```

### `test_upf_failover.sh`
Testa failover entre UPF-A e UPF-B.

### `add-subscriber.sh`
Provisiona subscriber no MongoDB (IMSI 001010000000001, DNN internet).

```bash
./scripts/add-subscriber.sh
```

### `apply-nat-host.sh`
Aplica sysctl (ip_forward) e iptables NAT no host para tráfego UE → internet. Idempotente.

```bash
./scripts/apply-nat-host.sh wlo1   # ou eth0, enp0s3, etc.
```

### `troubleshoot.sh`
Diagnóstico: rotas, iptables, tcpdump N2/N3/UE.

```bash
./scripts/troubleshoot.sh all        # Resumo
./scripts/troubleshoot.sh capture-n2  # NGAP/SCTP
./scripts/troubleshoot.sh capture-n3 # GTP-U
```

---

## Testes

### Teste de Conexão End-to-End

```bash
./scripts/test_ue_connection.sh
```

**O que é testado:**
- ✅ IP do UE atribuído
- ✅ Ping para internet (8.8.8.8, 8.8.4.4, 1.1.1.1)
- ✅ Resolução DNS
- ✅ Acesso HTTP
- ✅ Rota padrão
- ✅ Sessão PDU estabelecida

### Teste de Failover UPF

```bash
./scripts/test_upf_failover.sh
```

**O que é testado:**
- ✅ Failover UPF-A → UPF-B (quando UPF-A para)
- ✅ Failover UPF-B → UPF-A (quando UPF-B para)
- ✅ Conectividade contínua durante failover
- ✅ Taxa de sucesso dos testes

**Exemplo de saída:**
```
Teste 2: Failover UPF-A -> UPF-B
Parando UPF-A para forçar failover para UPF-B...
Aguardando failover (10 segundos)...
✅ Failover bem-sucedido! Conectividade mantida.
```

---

## Adicionar Novas UPFs

Para adicionar uma terceira UPF (UPF-C):

### 1. Criar arquivo de configuração

```bash
cp configs/open5gs/upf-a.yaml configs/open5gs/upf-c.yaml
```

### 2. Editar `upf-c.yaml`

Ajustar:
- `pfcp.server.address`: IP na rede N4 (ex: `10.40.0.23`)
- `gtpu.server.address`: IP na rede N3 (ex: `10.30.0.23`)
- `session.subnet`: Subnet não sobreposta (ex: `10.60.192.0/18`)
- `metrics.server.address`: IP na rede SBI (ex: `10.10.0.23`)

### 3. Adicionar UPF-C ao `smf.yaml`

```yaml
pfcp:
  client:
    upf:
      - address: 10.40.0.21  # UPF-A
      - address: 10.40.0.22  # UPF-B
      - address: 10.40.0.23  # UPF-C (NOVO)
```

### 4. Adicionar serviço ao `docker-compose.yml`

Copiar o serviço `upf-b` e ajustar:
- `container_name`: `open5gs-upf-c`
- `hostname`: `upf-c`
- `command`: `-c /etc/open5gs/upf-c.yaml`
- IPs nas redes N3, N4, N6
- `IPV4_TUN_ADDR`: IP do gateway da subnet (ex: `10.60.192.1/18`)

### 5. Reiniciar serviços

```bash
./scripts/down.sh
./scripts/up.sh
```

---

## Troubleshooting

### PCF/UDR não estão rodando

**Problema:** PCF e UDR reiniciando continuamente.

**Solução:**
1. Verificar se MongoDB está healthy: `docker compose ps mongodb`
2. Verificar logs: `docker compose logs pcf udr`
3. Verificar conectividade: `docker compose exec pcf ping -c 1 mongodb`

**Causa comum:** Open5GS tenta conectar em `mongodb://mongo/open5gs` (valor padrão). A entrada em `/etc/hosts` deve resolver "mongo" para "mongodb".

### UE não consegue acessar internet

**Problema:** UE tem IP mas não consegue fazer ping.

**Solução:**
1. Verificar se UPF está healthy: `docker compose ps upf-a upf-b`
2. Verificar logs do SMF: `docker compose logs smf | grep PFCP`
3. Verificar logs do UPF: `docker compose logs upf-a | grep PFCP`
4. Verificar rota no UE: `docker compose exec ueransim-ue ip route`

### gNB não consegue estabelecer conexão com AMF

**Problema:** `NG Setup procedure is failed. Cause: slice-not-supported`

**Solução:**
1. Verificar TAC do gNB corresponde ao AMF: `configs/ueransim/gnb.yaml`
2. Verificar PLMN (MCC/MNC) corresponde: `configs/ueransim/gnb.yaml` e `configs/open5gs/amf.yaml`
3. Remover SD do slice se AMF não suportar: `configs/ueransim/gnb.yaml`

### UPF não responde a associação PFCP

**Problema:** SMF não consegue associar com UPF.

**Solução:**
1. Verificar conectividade N4: `docker compose exec smf ping -c 1 10.40.0.21`
2. Verificar logs do UPF: `docker compose logs upf-a | grep PFCP`
3. Verificar se TUN está configurada: `docker compose exec upf-a ip addr show ogstun`

---

## Variáveis de Ambiente

Criar arquivo `.env` (opcional):

```bash
OPEN5GS_IMAGE=gradiant/open5gs:2.7.6
MONGODB_IMAGE=mongo:7.0
UERANSIM_IMAGE=gradiant/ueransim:3.2.7
DN_IMAGE=alpine:latest
```

---

## Integração com laboratório Kind (Aether / `aether-basic-deploy`)

Os mesmos modos **UERANSIM** e **srsRAN gNB + srsUE (ZMQ)** podem ser aplicados no cluster **`kind-ue5g`** no projeto irmão **`aether-basic-deploy`**: ver [`docs/ue-simulators-kind.md`](../aether-basic-deploy/docs/ue-simulators-kind.md) e os alvos `make ue-ueransim-deploy` / `make ue-srsue-zmq-deploy`.

---

## Documentação Adicional

- `docs/IP_ADDRESSING.md`: Justificativa dos endereços IP escolhidos
- `docs/CORRECOES_APLICADAS.md`: Correções aplicadas durante setup
- `docs/STATUS_FINAL.md`: Status final dos serviços
- `docs/CONEXAO_END_TO_END.md`: Detalhes da conexão end-to-end
- `docs/CORRECAO_PCF_UDR_FINAL.md`: Correções do PCF/UDR

---

## Status Atual

### ✅ Serviços Funcionando (12/14 - 86%)
- NRF, SCP, AMF, SMF, AUSF, UDM, NSSF
- UPF-A, UPF-B
- MongoDB, DN
- UERANSIM gNB, UERANSIM UE

### ⚠️ Serviços com Problemas (2/14 - 14%)
- PCF: Problema de conexão MongoDB (não crítico)
- UDR: Problema de conexão MongoDB (não crítico)

### ✅ Conectividade
- ✅ Conexão end-to-end funcionando
- ✅ UE consegue acessar internet
- ✅ Todas as interfaces de rede funcionando

---

**Última Atualização:** 2025-12-19
