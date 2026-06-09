# Explicação do docker-compose.yaml - free5GC

Este documento explica como o arquivo `docker-compose.yaml` do projeto free5GC está estruturado e como funciona.

## 📋 Visão Geral

O `docker-compose.yaml` define uma arquitetura completa de rede 5G Core (5GC) usando free5GC, incluindo:
- **Control Plane**: NRF, AMF, SMF, AUSF, UDM, UDR, PCF, NSSF
- **User Plane**: UPF
- **RAN**: srsRAN Project (gNB); UE: srsUE no host
- **Aplicações**: WebUI, NEF, CHF
- **Interworking**: N3IWF, TNGF

---

## 🌐 Rede Docker: `privnet`

### Configuração

```yaml
networks:
  privnet:
    ipam:
      driver: default
      config:
        - subnet: 10.100.200.0/24
    driver_opts:
      com.docker.network.bridge.name: br-free5gc
```

### Explicação

- **Subnet**: `10.100.200.0/24` - Todos os containers compartilham esta rede privada
- **Bridge**: `br-free5gc` - Nome customizado da bridge Docker para fácil identificação
- **Aliases DNS**: Cada serviço tem um alias DNS (ex: `amf.free5gc.org`) para comunicação via nome

### Por que uma única rede?

No free5GC, todos os componentes se comunicam via **Service-Based Interface (SBI)** usando HTTP/2, então uma única rede simplifica a configuração e permite comunicação direta entre todos os NFs.

---

## 🗄️ Volumes

### Volumes Definidos

```yaml
volumes:
  dbdata:  # Volume nomeado para dados do MongoDB
```

### Volumes Bind Mount

Cada serviço monta:
- **Configurações**: `./config/<servico>cfg.yaml:/free5gc/config/<servico>cfg.yaml`
- **Certificados**: `./cert:/free5gc/cert`
- **Logs**: `./logs/<servico>:/free5gc/log` (adicionado para persistência)

---

## 🔧 Serviços Principais

### 1. **MongoDB (db)**

```yaml
db:
  container_name: mongodb
  image: mongo:4.4
  command: mongod --port 27017
  volumes:
    - dbdata:/data/db
  networks:
    privnet:
      aliases:
        - db
```

**Função**: Banco de dados para NRF, UDR, UDM, CHF

**Dependências**: Nenhuma (serviço base)

---

### 2. **NRF (Network Repository Function)**

```yaml
free5gc-nrf:
  container_name: nrf
  image: free5gc/nrf:v4.2.0
  command: ./nrf -c ./config/nrfcfg.yaml
  environment:
    DB_URI: mongodb://db/free5gc
  depends_on:
    - db
```

**Função**: Registro e descoberta de Network Functions (NFs)

**Dependências**: `db` (MongoDB)

**Importância**: **CRÍTICO** - Todos os outros NFs dependem do NRF para se registrar e descobrir outros serviços

---

### 3. **AMF (Access and Mobility Management Function)**

```yaml
free5gc-amf:
  container_name: amf
  image: free5gc/amf:v4.2.0
  networks:
    privnet:
      ipv4_address: 10.100.200.16  # IP fixo
      aliases:
        - amf.free5gc.org
  depends_on:
    - free5gc-nrf
```

**Função**: 
- Gerencia registro e mobilidade do UE
- Interface N2 (NGAP) com gNB
- Interface SBI com outros NFs

**IP Fixo**: `10.100.200.16` - Necessário porque o gNB precisa conhecer o IP do AMF para conexão NGAP

**Dependências**: `free5gc-nrf`

---

### 4. **SMF (Session Management Function)**

```yaml
free5gc-smf:
  container_name: smf
  image: free5gc/smf:v4.2.0
  command: ./smf -c ./config/smfcfg.yaml -u ./config/uerouting.yaml
  depends_on:
    - free5gc-nrf
    - free5gc-upf
```

**Função**:
- Gerencia sessões PDU (PDU Sessions)
- Interface N4 (PFCP) com UPF
- Interface SBI com AMF, PCF, UDM

**Dependências**: `free5gc-nrf`, `free5gc-upf`

---

### 5. **UPF (User Plane Function)**

```yaml
free5gc-upf:
  container_name: upf
  image: free5gc/upf:v4.2.0
  command: bash -c "./upf-iptables.sh && ./upf -c ./config/upfcfg.yaml"
  cap_add:
    - NET_ADMIN
```

**Função**:
- Encaminhamento de pacotes de dados (User Plane)
- Interface N3 (GTP-U) com gNB
- Interface N4 (PFCP) com SMF
- Interface N6 com Data Network (DN)

**Capabilities**: `NET_ADMIN` - Necessário para configurar rotas e iptables

**Script `upf-iptables.sh`**: Configura regras de NAT/forwarding para permitir tráfego do UE para internet

---

### 6. **srsRAN gNB**

```yaml
srsran-gnb:
  build:
    context: .
    dockerfile: Dockerfile.srsRAN
  image: srsran-gnb:local
  container_name: srsran-gnb
  networks:
    privnet:
      ipv4_address: 10.100.200.50
  volumes:
    - ../gNB/configs:/etc/srsran:ro
    - ../gNB/logs:/logs
  entrypoint: ["/bin/sh","/etc/srsran/entrypoint.sh"]
  cap_add:
    - NET_ADMIN
  restart: no
```

**Função**: gNB (base station 5G) — srsRAN Project. UE (srsUE) corre no host e conecta ao gNB via ZMQ quando configurado com `gnb-zmq-srsue.yml`.

**Dependências**: `free5gc-amf` (N2/NGAP), `free5gc-upf` (N3/GTP-U). Config em `gNB/configs/gnb.yml`; variante ZMQ para srsUE em `gNB/configs/gnb-zmq-srsue.yml`.

---

## 🔗 Dependências e Ordem de Inicialização

### Árvore de Dependências

```
db (MongoDB)
  └── free5gc-nrf
      ├── free5gc-amf
      │   ├── srsran-gnb (gNB)
      │   ├── free5gc-n3iwf
      │   └── free5gc-tngf
      ├── free5gc-ausf
      ├── free5gc-nssf
      ├── free5gc-pcf
      ├── free5gc-udm
      │   └── db
      ├── free5gc-udr
      │   └── db
      ├── free5gc-smf
      │   └── free5gc-upf
      ├── free5gc-nef
      ├── free5gc-chf
      │   ├── db
      │   └── free5gc-webui
      └── free5gc-webui
```

### Ordem Recomendada de Inicialização

1. **db** (MongoDB)
2. **free5gc-nrf** (Registro de NFs)
3. **Control Plane** (AMF, AUSF, NSSF, PCF, UDM, UDR) - podem iniciar em paralelo
4. **free5gc-upf** (User Plane)
5. **free5gc-smf** (depende de NRF e UPF)
6. **srsran-gnb** (gNB - depende de AMF e UPF)
7. **Serviços opcionais** (WebUI, NEF, CHF, N3IWF, TNGF)

---

## 🔐 Segurança e Configuração

### Certificados TLS

Todos os serviços montam `./cert:/free5gc/cert` para certificados TLS usados na comunicação SBI.

### Variáveis de Ambiente

- `GIN_MODE: release` - Modo de produção do framework Gin (Go)
- `DB_URI: mongodb://db/free5gc` - URI de conexão com MongoDB

### Capabilities Especiais

- `NET_ADMIN`: UPF, srsran-gnb, N3IWF, TNGF - Para configuração de rede
- `network_mode: host`: TNGF - Usa rede do host diretamente

---

## 📊 Interfaces 5G

### N2 (NGAP) - AMF ↔ gNB
- **Protocolo**: SCTP
- **Porta**: 38412
- **Função**: Controle de acesso e mobilidade

### N3 (GTP-U) - gNB ↔ UPF
- **Protocolo**: UDP (GTP-U)
- **Porta**: 2152
- **Função**: Encapsulamento de dados do usuário

### N4 (PFCP) - SMF ↔ UPF
- **Protocolo**: UDP (PFCP)
- **Porta**: 8805
- **Função**: Controle da sessão PDU

### N6 - UPF ↔ Data Network
- **Protocolo**: IP
- **Função**: Conexão com internet/externa

### SBI (Service-Based Interface) - Entre NFs
- **Protocolo**: HTTP/2
- **Porta**: 8000 (padrão)
- **Função**: Comunicação entre Network Functions

---

## 🚀 Como Funciona na Prática

### 1. Inicialização

Quando você executa `docker compose up`:

1. Docker cria a rede `privnet` (10.100.200.0/24)
2. Inicia `db` (MongoDB)
3. Inicia `free5gc-nrf` e aguarda registro no MongoDB
4. Outros serviços iniciam e se registram no NRF
5. AMF abre porta 38412 para NGAP
6. gNB conecta ao AMF via SCTP
7. SMF associa com UPF via PFCP
8. Sistema está pronto para UEs se conectarem

### 2. Registro de UE

1. UE (srsUE no host) envia mensagem NAS para gNB (via ZMQ ou rádio)
2. gNB encapsula em NGAP e envia para AMF (N2)
3. AMF autentica UE via AUSF
4. AMF solicita sessão PDU via SMF
5. SMF configura UPF via PFCP (N4)
6. UPF cria túnel GTP-U com gNB (N3)
7. UE recebe IP e pode acessar internet via N6

### 3. Comunicação de Dados

1. UE envia pacote IP
2. gNB encapsula em GTP-U e envia para UPF (N3)
3. UPF desencapsula e encaminha para internet (N6)
4. Resposta segue caminho inverso

---

## 📝 Notas Importantes

### IPs Fixos

- **AMF**: `10.100.200.16` - Necessário porque gNB precisa conhecer este IP
- **N3IWF**: `10.100.200.15` - Para interworking não-3GPP
- **N3UE**: `10.100.200.203` - Para cliente N3IWF

### Aliases DNS

Todos os serviços têm aliases como `amf.free5gc.org`, `smf.free5gc.org`, etc. Isso permite comunicação via nome ao invés de IP.

### Logs

Logs são montados em `./logs/<servico>/` para persistência e análise.

---

## 🔧 Troubleshooting

### Verificar conectividade

```bash
# Ver IPs dos containers
docker compose exec free5gc-amf ip addr show

# Testar ping entre serviços
docker compose exec free5gc-amf ping -c 1 10.100.200.10  # NRF
```

### Ver logs

```bash
# Logs de um serviço
docker compose logs free5gc-amf

# Logs em tempo real
docker compose logs -f free5gc-amf
```

### Verificar registros no NRF

```bash
# Ver logs do NRF
docker compose logs free5gc-nrf | grep "NF registered"
```

---

## 📚 Referências

- [free5GC Documentation](https://free5gc.org/)
- [3GPP TS 23.501 - System Architecture](https://www.3gpp.org/DynaReport/23501.htm)
- [3GPP TS 23.502 - Procedures](https://www.3gpp.org/DynaReport/23502.htm)

