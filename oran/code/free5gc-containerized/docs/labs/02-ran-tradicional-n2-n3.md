# Roteiro 02 — RAN tradicional (gNB monolítico), N2/N3 e teste E2E com UE

**Objetivos:** ligar o **gNB integrado** (srsRAN Project) ao AMF; validar **N2 (NGAP/SCTP)** e **N3 (GTP-U)**; **conectar um UE (srsUE)** e comprovar o fluxo ponta a ponta; **capturar e analisar** o tráfego com o Wireshark.

**Pré-requisito:** Roteiro 01 concluído (core ativo, assinante criado com webui ou `./scripts/add-subscriber.sh`).

**Foco:** testes E2E e evidência de protocolos por captura de pacotes.

**Caminhos:** os comandos assumem que você está na pasta `code/free5gc-containerized` do repositório (ajuste se o seu clone estiver em outro nível de pastas).

---

## 1. Subida da RAN tradicional

Com o **core** já em execução (`core/scripts/up.sh`):

```bash
cd gNB_traditional
./scripts/up.sh
```

A primeira execução pode demorar (**build** da imagem `srsran-gnb:local`).

**O que esperar (logs):**

- Ao final de `./scripts/up.sh`, `docker compose ps` deve mostrar o serviço **Up** com mapeamento **`0.0.0.0:2000->2000`** (apenas a porta 2000; a 2001 fica no host para o srsUE).
- O processo `gnb` não inicia no container por padrão (`GNB_AUTO_START=0`). Confirme com:

```bash
docker logs srsran-gnb-tradicional 2>&1 | tail -40
```

Trechos típicos de **sucesso** (não precisam ser idênticos byte a byte):

- Espera pelo AMF: `waiting for eth0 + route + AMF reachability (10.100.200.16)`
- Arranque do binário: `gnb -c /etc/srsran/gnb-zmq-srsue.yml`
- Célula NR: `dl_arfcn=368500 (n3)`, `dl_freq=1842.5 MHz` (banda 3, SCS 15 kHz)
- N2: `N2: Connection to AMF on 10.100.200.16:38412 completed` e `==== gNB started ===`

Avisos de **prioridade de agendamento** (`Scheduling priority … Not enough privileges`) são comuns em Docker e **não** invalidam o laboratório.

**Verificação:**

```bash
docker compose ps
docker ps --filter name=srsran-gnb-tradicional --format '{{.Names}} {{.Status}}'
```

**Evidência obrigatória:** captura de tela ou texto de `docker ps` mostrando `srsran-gnb-tradicional` **Up**.

---

## 2. Identidade do nó RAN (para o relatório)

Para o teste **E2E com srsUE (ZMQ)**, o arquivo em uso é o **`gNB_traditional/configs/gnb-zmq-srsue.yml`** (padrão do `docker-compose` e do `./scripts/up.sh`).

Abra esse arquivo e **transcreva para o relatório** (ou anexe *print*) os campos:

- `gnb_id` / `gnb_id_bit_length`
- Em `cu_cp.amf`: `bind_addr` (IP do gNB na rede Docker), `addr` e `port` do AMF
- Em `cell_cfg`: `plmn`, `tac`, `pci`, `band`, `dl_arfcn`, `common_scs`

**Pergunta-guia:** qual o endereço IPv4 do gNB na rede `free5gc-privnet`? (valor esperado neste lab: **10.100.200.50**.)

**Nota:** o arquivo `gnb.yml` usa **ru_dummy** (sem rádio ZMQ para o srsUE) e serve para cenários em que só se valida N2 sem UE real; para o Roteiro 02 com srsUE, o relatório deve referir **`gnb-zmq-srsue.yml`**.

---

## 3. Validação N2 / NGAP

A partir da pasta `core/`:

```bash
cd ../core
./scripts/validate-n2-ngap.sh
```

**Evidência obrigatória:** saída **completa** do script (anexo `.txt`).

**O que esperar:** o script deve indicar sucesso na associação N2/NGAP (mensagens de verificação e, em geral, referência a SCTP/NG Setup). Se falhar, confira se o gNB está **Up** e se o AMF responde em `10.100.200.16:38412`.

**Complemento manual:**

```bash
tail -n 80 ../gNB_traditional/logs/gnb.log
docker logs srsran-gnb-tradicional 2>&1 | tail -n 60
docker logs --tail 60 amf 2>/dev/null | grep -iE 'ng|sctp|gnb' || true
```

(Os contentores do core usam os nomes `amf`, `smf`, etc.; confira com `docker ps` se o seu compose for diferente.)

**Evidência:** trecho de log em que apareça **NG Setup** ou estabelecimento da associação com o AMF (destaque a linha relevante no relatório).

**Exemplo de trecho útil no log do gNB** (arquivo `gNB_traditional/logs/gnb.log`):

- `Tx PDU: NGSetupRequest` seguido de `Rx PDU: NGSetupResponse`
- `Connected to AMF. Supported PLMNs: 20893`

---

## 4. Captura N2 e análise no Wireshark (obrigatório)

A captura na interface N2 é **obrigatória** para o relatório. Permite observar **SCTP** e **NGAP**.

### 4.1 Capturar tráfego N2

Requer permissão para usar `tcpdump` na bridge do host. **Fluxo recomendado:**

1. Inicie o script de captura e deixe a correr.
2. Em outro terminal: `docker restart srsran-gnb-tradicional`
3. Aguarde 10–15 s para o handshake SCTP e o NG Setup.
4. Interrompa a captura com **Ctrl+C** (o `tcpdump` mostra quantos pacotes foram capturados).

```bash
cd ../core
./scripts/capture-n2.sh
```

O arquivo `.pcap` fica em `core/captures/n2_YYYYMMDD_HHMMSS.pcap`. Por padrão usa-se a interface `any`; para restringir à bridge Docker: `BRIDGE=br-free5gc ./scripts/capture-n2.sh` (ajuste o nome da bridge com `ip link` se necessário).

Alternativa direta no host:

```bash
sudo tcpdump -i any -nn -l 'sctp and port 38412'
```

### 4.2 Abrir no Wireshark e aplicar filtros

1. Abra o `.pcap` no Wireshark.
2. **Filtro recomendado:** `sctp.port == 38412`
3. **O que observar:**
   - **Handshake SCTP:** INIT (gNB→AMF), INIT-ACK (AMF→gNB), COOKIE-ECHO, COOKIE-ACK.
   - **NGAP:** pacotes SCTP DATA com payload NGAP — expanda **SCTP** → **NGAP** para ver `NGSetupRequest` e `NGSetupResponse`.

### 4.3 Filtros úteis no Wireshark

| Filtro | Descrição |
| ------ | --------- |
| `sctp.port == 38412` | Tráfego N2 (SCTP na porta NGAP). |
| `ngap` | PDUs NGAP (se o dissector estiver disponível). |
| `sctp.chunk_type == 0` | Chunks SCTP DATA (carregam NGAP). |

### 4.4 Evidência obrigatória

- **Print do Wireshark** com: (1) handshake SCTP; (2) pelo menos um pacote NGAP (`NGSetupRequest` ou `NGSetupResponse`) com painel de detalhes expandido.
- **Texto no relatório:** o que cada etapa do SCTP representa e o que o NG Setup estabelece entre gNB e AMF.

---

## 5. Conexão do UE (srsUE) — obrigatório para E2E

A conectividade do UE é **obrigatória** neste roteiro. O teste ponta a ponta exige registo na rede e **sessão PDU** com IP atribuído.

### 5.1 Pré-requisitos e configuração

- **Core** ativo e **assinante** criado (IMSI `208930000000001`, alinhado a `gNB_traditional/configs/ue_srsue.conf`).
- **gNB** com **`gnb-zmq-srsue.yml`** (já é o padrão ao usar `./scripts/up.sh` em `gNB_traditional`).
- **srsUE** instalado no host (srsRAN 4G), conforme [core/docs/CONECTAR_UE.md](../../core/docs/CONECTAR_UE.md).

**Ordem recomendada:** core → `./scripts/up.sh` no `gNB_traditional` → só depois **`srsue`** no host (o gNB pode ligar-se ao UL ZMQ quando o srsUE já fez bind na porta 2001).

### 5.2 Subir o srsUE

No host, a partir da pasta `gNB_traditional` (onde está `configs/ue_srsue.conf`):

```bash
cd gNB_traditional
srsue configs/ue_srsue.conf
```

### 5.3 Logs esperados — srsUE (sucesso)

Os alunos devem comparar a saída com o padrão abaixo. Variações menores (avisos de *real-time priority*, *TX gain*) são aceitáveis.

**Inicialização do rádio ZMQ:**

- `Opening 1 channels in RF device=zmq` — **importante:** deve aparecer **1 canal**; se aparecer **2**, confira `[rat.eutra] nof_carriers = 0` no `ue_srsue.conf` (sem isso, faltam portas ZMQ no segundo canal).
- `CH0 rx_port=tcp://127.0.0.1:2000` e `CH0 tx_port=tcp://0.0.0.0:2001`

**Acesso e sessão:**

- `Attaching UE...`
- `Random Access Complete` com **C-RNTI** (ex.: `c-rnti=0x4601`)
- `RRC Connected`
- `PDU Session Establishment successful. IP: 10.60.0.x` (o IP exato depende do SMF/UPF; no free5GC padrão costuma ser do pool **10.60.0.0/16**)
- `RRC NR reconfiguration successful.`

**Evidência obrigatória:** copiar para o relatório (ou anexo `.txt`) o trecho desde `Opening 1 channels` até a linha do **PDU Session** e **RRC Connected**.

### 5.4 Logs esperados — core (AMF / SMF)

Enquanto o UE se registra e estabelece a sessão, é útil acompanhar (a partir de `gNB_traditional`, `../core` é a pasta do core):

```bash
cd ../core
docker logs --tail 80 amf
docker logs --tail 80 smf
```

**AMF (indicativos de sucesso):** mensagens de transporte NAS no uplink; referência ao SUPI/IMSI do assinante; ausência repetida de falhas SCTP após o **registro** estável.

**SMF:** criação de contexto de sessão PDU (`PDU Session`, `smContext`); em tráfego contínuo podem aparecer relatórios de uso / *charging* (`UsageReport`, etc.).

Se o N2 “oscilar” (muitos `SCTP_SHUTDOWN` ao reiniciar o gNB várias vezes), reinicie o serviço AMF **uma vez** e volte a subir apenas **uma** instância do gNB.

### 5.5 Teste de conectividade (ping / navegação)

Com a sessão PDU ativa, o srsUE cria a interface **`tun_srsue`** (se não estiver a usar *network namespace*).

**Ping pela interface do UE:**

```bash
ping -c 4 -I tun_srsue 8.8.8.8
```

**O que esperar:** `0% packet loss` e tempos de ida e volta em milissegundos.

**Evidência obrigatória:** saída do comando com sucesso (ou captura de navegação Web pela mesma rota, se configurado encaminhamento/DNS).

Para detalhes de rotas no host e *namespace*, veja [core/docs/CONECTAR_UE.md](../../core/docs/CONECTAR_UE.md).

---

## 6. Captura N3 e análise no Wireshark (obrigatório)

A captura N3 só faz sentido **com UE associado** e **sessão PDU** estabelecida. Mostra **GTP-U** (interface N3) entre gNB e UPF.

### 6.1 Capturar tráfego N3

Inicie a captura **antes** ou **durante** o ping a partir do UE (com o *working directory* em `gNB_traditional`, faça `cd ../core`; se já estiver em `core/`, execute só o script):

```bash
cd ../core
./scripts/capture-n3.sh
```

Guarde o `.pcap` em `core/captures/n3_YYYYMMDD_HHMMSS.pcap`.

### 6.2 Abrir no Wireshark e aplicar filtros

1. Abra o `.pcap`.
2. **Filtro recomendado:** `udp.port == 2152`
3. **O que observar:**
   - **GTP-U:** UDP porta 2152 com cabeçalho GTP-U.
   - **Echo Request/Response** entre gNB e UPF (se aplicável).
   - **G-PDU:** tráfego do UE encapsulado — expanda **GTP-U** → **G-PDU** para ver o IP interno.

### 6.3 Filtros úteis no Wireshark

| Filtro | Descrição |
| ------ | --------- |
| `udp.port == 2152` | Tráfego GTP-U (N3). |
| `gtpu` | GTP-U (se o dissector existir). |
| `gtpu.teid == <valor>` | Filtrar por TEID. |

### 6.4 Evidência obrigatória

- **Print do Wireshark:** (1) pacotes GTP-U na porta 2152; (2) pelo menos um G-PDU com tráfego do UE (ex.: ICMP do ping).
- **Texto no relatório:** diferença entre **N2** (controle) e **N3** (dados); papel do **GTP-U** e do **TEID**.

---

## 7. Validação E2E (scripts)

Consolide a evidência a partir da pasta **`core/`**:

```bash
cd ../core
./scripts/validate-dataplane.sh
./scripts/test-e2e.sh
```

(Se o seu terminal já estiver em `core/`, não use `cd ../core`.)

**Evidência obrigatória:** saídas dos dois scripts (anexo `.txt` ou prints).

**O que esperar:** conclusão sem erro crítico; em caso de falha, confira UPF, rotas e se o ping do passo 5.5 funcionou.

---

## 8. Encerramento

Com o terminal em **`core/`**:

```bash
cd ../gNB_traditional
./scripts/down.sh
```

(O core pode permanecer ativo para o Roteiro 03.)

---

## Checklist do Roteiro 02

- [ ] Container `srsran-gnb-tradicional` ativo; `docker logs` com **gNB started** e N2 ao AMF.
- [ ] Parâmetros de **`gnb-zmq-srsue.yml`** (e não só `gnb.yml`) descritos no relatório quando o E2E com srsUE foi feito.
- [ ] Resultado de `./scripts/validate-n2-ngap.sh` (anexo completo).
- [ ] Trecho de logs do gNB (`gNB_traditional/logs/gnb.log` ou `docker logs`) e do AMF com NGAP/N2.
- [ ] **Captura N2:** arquivo `.pcap` e *print* do Wireshark (SCTP + NGAP).
- [ ] **UE conectado:** log do srsUE com **1 canal ZMQ**, **RRC Connected** e **PDU Session**; ping ou navegação com sucesso.
- [ ] **Captura N3:** arquivo `.pcap` e *print* do Wireshark (GTP-U / G-PDU).
- [ ] Saídas de `validate-dataplane.sh` e `test-e2e.sh`.
- [ ] Parágrafo no relatório: diferença entre **N2** (controle) e **N3** (plano do usuário) neste laboratório.

**Referências:** [core/docs/VALIDATION_E2E.md](../../core/docs/VALIDATION_E2E.md), [core/docs/CONECTAR_UE.md](../../core/docs/CONECTAR_UE.md).

---

## Resumo de problemas frequentes (para orientação dos estudantes)

| Sintoma | Causa provável | O que verificar |
| ------- | -------------- | ---------------- |
| `Address already in use` na porta 2001 (srsUE) | Porta 2001 publicada no Docker (`2001:2001`) | No `docker-compose` do gNB deve existir **só** `2000:2000`. |
| `Opening 2 channels` e erro de portas ZMQ | LTE default 1 + NR 1 ⇒ dois canais RF | Em `ue_srsue.conf`: `[rat.eutra] nof_carriers = 0`. |
| `Attaching UE...` sem progresso | gNB não a correr ou só o container sem `gnb` | `docker logs` deve mostrar `gnb -c ...` e célula ativa; `./scripts/up.sh` usa `GNB_AUTO_START=1` por defeito. |
| N2 instável no AMF após muitos restarts | Estado SCTP antigo | Reiniciar o AMF **uma vez** e manter uma única instância do gNB. |
