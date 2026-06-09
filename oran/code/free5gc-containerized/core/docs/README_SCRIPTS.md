# Scripts de Gerenciamento - free5GC

Este documento descreve os scripts criados para gerenciar o sistema free5GC.

## 📋 Scripts Disponíveis

### 1. `scripts/up.sh` - Inicializar Sistema

Inicializa todos os serviços do free5GC na ordem correta.

**Uso:**
```bash
./scripts/up.sh
```

**O que faz:**
- Verifica se Docker está rodando
- Cria diretórios de logs
- Habilita IP forwarding (necessário para UPF)
- Inicia serviços na ordem:
  1. MongoDB
  2. NRF
  3. Control Plane (AMF, AUSF, NSSF, PCF, UDM, UDR)
  4. UPF
  5. SMF
  6. srsRAN gNB
  7. Serviços opcionais (WebUI, NEF, CHF)
- Verifica saúde dos serviços principais
- Mostra status final

---

### 2. `scripts/down.sh` - Encerrar Sistema

Para todos os containers do free5GC.

**Uso:**
```bash
# Parar containers (preserva volumes)
./scripts/down.sh

# Parar containers e remover volumes (apaga dados do MongoDB)
./scripts/down.sh --volumes
```

**O que faz:**
- Para todos os containers
- Opcionalmente remove volumes (com confirmação)
- Mostra status final

---

### 3. `scripts/healthcheck.sh` - Verificar Saúde

Verifica o status e saúde de todos os serviços.

**Uso:**
```bash
./scripts/healthcheck.sh
```

**O que verifica:**
- Status dos containers (rodando/parado)
- Processos dos serviços principais
- Conectividade de rede
- NG Setup (gNB ↔ AMF)
- Registro de NFs no NRF
- Associação PFCP (SMF ↔ UPF)
- Logs recentes

---

### 4. `scripts/test.sh` - Testar Sistema

Executa testes automatizados do sistema.

**Uso:**
```bash
./scripts/test.sh
```

**Testes executados:**
1. Acessibilidade do NRF
2. Registro do AMF no NRF
3. NG Setup (gNB ↔ AMF)
4. Associação PFCP (SMF ↔ UPF)
5. Conectividade de rede
6. Verificação de erros críticos nos logs

**Saída:**
- ✅ Testes passados
- ❌ Testes falhados
- Resumo final com status

---

### 5. `scripts/validate-n2-ngap.sh` - Validação N2/NGAP

Validação objetiva do plano de controle: SCTP estabelecido, NG Setup e logs consistentes (srsRAN gNB ↔ AMF).

**Uso:**
```bash
./scripts/validate-n2-ngap.sh
```

**Critérios:** containers up, SCTP em LISTEN/ESTABLISHED, logs AMF (gNB aceito, NG Setup), logs gNB (conexão AMF, sem falha N2), RestartCount do gNB. Ref: `docs/VALIDATION_E2E.md`.

---

### 6. `scripts/capture-n2.sh` e `scripts/capture-n3.sh` - Capturas de rede

Capturam tráfego na bridge Docker (`br-free5gc`). Exigem `tcpdump` e permissão no host.

- **capture-n2.sh:** SCTP porta 38412 (N2/NGAP). Arquivo em `captures/n2_*.pcap`.
- **capture-n3.sh:** UDP porta 2152 (GTP-U N3). Arquivo em `captures/n3_*.pcap`.

**Uso:**
```bash
./scripts/capture-n2.sh   # Ctrl+C para parar
./scripts/capture-n3.sh
```

---

### 7. `scripts/validate-dataplane.sh` - Validação plano de dados

Framework para validar PFCP, sessões PDU e subscriber quando UE estiver ativo.

**Uso:**
```bash
./scripts/validate-dataplane.sh
```

---

### 8. `scripts/checklist-e2e.sh` - Checklist validação E2E

Checklist técnico de validação final (itens do `docs/VALIDATION_E2E.md` § 4).

**Uso:**
```bash
./scripts/checklist-e2e.sh
```

---

## 📁 Estrutura de Diretórios

```
free5gc-containerized/
├── scripts/
│   ├── up.sh              # Inicializar sistema
│   ├── down.sh            # Encerrar sistema
│   ├── healthcheck.sh     # Verificar saúde
│   └── test.sh            # Testar sistema
├── logs/                  # Logs persistentes
│   ├── amf/
│   ├── ausf/
│   ├── nrf/
│   ├── smf/
│   ├── upf/
│   └── srsran/
├── config/                # Configurações
├── cert/                  # Certificados TLS
└── docker-compose.yaml    # Definição dos serviços
```

---

## 🔧 Volumes de Logs

Os logs são persistidos em `./logs/<servico>/` através de volumes bind mount:

- **AMF**: `./logs/amf:/free5gc/log`
- **AUSF**: `./logs/ausf:/free5gc/log`
- **NRF**: `./logs/nrf:/free5gc/log`
- **SMF**: `./logs/smf:/free5gc/log`
- **UPF**: `./logs/upf:/free5gc/log`
- **srsRAN gNB**: `../gNB/logs:/logs`

**Vantagens:**
- Logs persistem mesmo após parar containers
- Fácil acesso aos logs do host
- Permite análise e troubleshooting

---

## 🚀 Fluxo de Uso Recomendado

### 1. Inicializar Sistema

```bash
./scripts/up.sh
```

Aguarde alguns segundos para todos os serviços iniciarem.

### 2. Verificar Saúde

```bash
./scripts/healthcheck.sh
```

Verifique se todos os serviços estão rodando corretamente.

### 3. Testar Sistema

```bash
./scripts/test.sh
```

Execute testes automatizados para validar funcionamento.

### 4. Ver Logs (se necessário)

```bash
# Logs de um serviço específico
docker compose logs free5gc-amf

# Logs em tempo real
docker compose logs -f free5gc-amf

# Logs de todos os serviços
docker compose logs
```

### 5. Encerrar Sistema

```bash
# Preservar dados
./scripts/down.sh

# Remover tudo (incluindo dados do MongoDB)
./scripts/down.sh --volumes
```

---

## 🔍 Troubleshooting

### Serviço não inicia

1. Verifique logs: `docker compose logs <servico>`
2. Verifique dependências: `docker compose ps`
3. Verifique conectividade: `./scripts/healthcheck.sh`

### NG Setup não estabelecido

1. Verifique se AMF está rodando: `docker compose ps free5gc-amf`
2. Verifique logs do AMF: `docker compose logs free5gc-amf | grep NG`
3. Verifique se gNB está rodando: `docker compose ps srsran-gnb`
4. Execute validação N2: `./scripts/validate-n2-ngap.sh`; consulte `docs/README_TROUBLESHOOTING.md` (N2/SCTP, bind_addr)

### PFCP não associado

1. Verifique se SMF está rodando: `docker compose ps free5gc-smf`
2. Verifique se UPF está rodando: `docker compose ps free5gc-upf`
3. Verifique logs do SMF: `docker compose logs free5gc-smf | grep PFCP`

---

## 📚 Documentação Adicional

- **docker-compose.yaml**: Veja `docs/DOCKER_COMPOSE_EXPLAINED.md` para explicação detalhada
- **Validação E2E:** `docs/VALIDATION_E2E.md` (plano de controle/dados, diagnóstico SCTP, tcpdump, checklist)
- **free5GC**: https://free5gc.org/
- **srsRAN Project**: https://github.com/srsran/srsRAN_Project
- **srsUE (conectar UE):** `docs/CONECTAR_UE.md`

---

## ✅ Checklist de Funcionamento

Após inicializar, verifique:

- [ ] MongoDB está rodando
- [ ] NRF está rodando e acessível
- [ ] AMF está registrado no NRF
- [ ] NG Setup estabelecido (gNB ↔ AMF)
- [ ] SMF está registrado no NRF
- [ ] PFCP associado (SMF ↔ UPF)
- [ ] UPF está rodando
- [ ] gNB está rodando e conectado ao AMF
- [ ] Nenhum erro crítico nos logs

Se todos os itens estiverem marcados, o sistema está funcionando corretamente! 🎉

