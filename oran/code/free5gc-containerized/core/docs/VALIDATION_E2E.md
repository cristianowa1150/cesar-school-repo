# Plano de Validação End-to-End — Lab 5G SA (srsRAN gNB + free5GC)

**Escopo:** Plano de controle (N2/NGAP) e plano de dados (N3/GTP-U), diagnóstico profissional e checklist de validação.  
**Rede:** Docker bridge `free5gc_privnet` (subnet `10.100.200.0/24`).  
**AMF:** `10.100.200.16`, **gNB:** `10.100.200.50`, **UPF:** alias `upf.free5gc.org`.

**UE:** O lab usa **srsUE** (srsRAN 4G), que suporta **5G NR Standalone (SA)**. A combinação srsUE ↔ srsRAN Project gNB ↔ free5GC é um teste E2E 5G SA adequado (registro, sessão PDU, dados). Ver `docs/CONECTAR_UE.md`.

**Scripts associados (executar a partir do diretório `free5gc`):**

| Script | Uso |
|--------|-----|
| `scripts/validate-n2-ngap.sh` | Validação N2/SCTP e NG Setup (critérios objetivos). |
| `scripts/capture-n2.sh` | Captura tcpdump N2 (SCTP 38412) na bridge. |
| `scripts/capture-n3.sh` | Captura tcpdump N3 (GTP-U 2152) na bridge. |
| `scripts/validate-dataplane.sh` | Framework de validação do plano de dados (PFCP, PDU, subscriber). |
| `scripts/checklist-e2e.sh` | Checklist de validação final (itens § 4). |

---

## 1. Testes End-to-End (E2E)

### 1.1 Plano de Controle (NGAP / N2)

#### Objetivo

Validar que o **NG Setup** está estabelecido entre srsRAN gNB e free5GC AMF, com associação SCTP ativa e troca NGAP correta.

#### Pré-requisitos

- Core (AMF, NRF, etc.) e gNB em execução.
- Conectividade IP entre gNB e AMF já validada (ping).

#### 1.1.1 Validação da associação SCTP

**Importante:** NGAP/N2 usa **SCTP** na porta 38412. No `ss`, use **`ss -S`** (SCTP), **não** `ss -t` (TCP). No host, o socket costuma existir só no *network namespace* do container AMF — `ss` no host pode não mostrar nada mesmo com N2 OK.

**Onde executar:** host (acesso à bridge) ou container AMF (se tiver `ss`/`lsof`).

```bash
# Listar sockets SCTP em LISTEN (AMF)
ss -Slnp | grep 38412
# Esperado: linha sctp LISTEN em *:38412 (ou no IP do AMF)

# Listar associações SCTP estabelecidas
ss -Snp state established | grep 38412
# Esperado: par 10.100.200.16:38412 <-> 10.100.200.50:<ephemeral> (se a associação ainda estiver ativa no momento do comando)
```

**Dentro do container AMF (recomendado se o host não mostrar SCTP):**

```bash
docker compose exec -T free5gc-amf ss -Slnp
docker compose exec -T free5gc-amf ss -Snp state established | grep 38412
```

**Critério de sucesso (forte):** associação SCTP `ESTABLISHED` visível com `ss -S`. **Critério alternativo:** logs do AMF com `NGSetupRequest` / `NG-Setup response` — a associação pode fechar logo após o procedimento (`SCTP_SHUTDOWN_EVENT`), então `ss` no host pode ficar vazio mesmo com N2 funcional.

#### 1.1.2 Verificação de troca NGAP (NGSetupRequest / NGSetupResponse)

**Logs AMF (free5GC):**

```bash
docker compose logs amf 2>&1 | grep -iE "ngap|ng-setup|sctp|gNB"
```

**Evidências mínimas esperadas:**

| Evento | Log esperado (exemplo) |
|--------|-------------------------|
| Aceite SCTP | `gNB-N2 accepted [10.100.200.50]` ou equivalente |
| NG Setup | `NGSetupRequest` recebido e `NG-Setup response` enviado |
| gNB registrado | `[Added] Number of gNBs is now 1` ou similar |

**Logs gNB (srsRAN):**

```bash
docker compose logs srsran-gnb 2>&1 | grep -iE "AMF|NGAP|SCTP|CU-CP|NgSetup"
```

**Evidências mínimas esperadas:**

| Evento | Log esperado (exemplo) |
|--------|-------------------------|
| Conexão AMF | `AMF connection established` ou `Connecting to AMF` seguido de sucesso |
| NGAP | `Sending NgSetupRequest` e posteriormente **sem** `NGSetupFailure` |
| CU-CP | `CU-CP started successfully` (após estabelecimento N2) |

**Critério de sucesso:**  
- AMF mostra gNB aceito e NG Setup respondido com sucesso.  
- gNB mostra conexão AMF estabelecida e NgSetupRequest enviado, sem falha fatal.

#### 1.1.3 Comandos de evidência rápida

```bash
# Contar NG Setup nos logs AMF
docker compose logs amf 2>&1 | grep -c "NGSetupRequest\|NG-Setup response\|gNB-N2 accepted"

# Verificar que gNB não saiu por falha N2
docker compose logs srsran-gnb 2>&1 | tail -30
# Não deve aparecer: "Failed to connect to AMF", "Network is unreachable", exit imediato
```

#### 1.1.4 Uso de tcpdump (N2)

Ver seção **3.1** para captura e filtros. Evidência mínima: handshake SCTP (INIT, INIT-ACK, COOKIE-ECHO, COOKIE-ACK) e tráfego na porta 38412 entre 10.100.200.50 e 10.100.200.16.

---

### 1.2 Plano de Usuário (Data Plane) — Preparação para UE

#### Objetivo

Deixar o ambiente e o **framework de teste** prontos para quando um UE (srsUE) for adicionado: pontos de observação e critérios de validação do fluxo de dados.

#### 1.2.1 Pontos de observação

| Ponto | Onde | O que observar |
|-------|------|----------------|
| **N3 (RAN ↔ UPF)** | Interface do UPF / bridge | GTP-U (UDP 2152): encapsulamento downlink (UPF→gNB) e uplink (gNB→UPF). |
| **N6 (UPF ↔ DN)** | Interface do UPF ou host | IP desencapsulado (pool UE, ex. 10.60.0.0/16) saindo para a rede de dados. |
| **gNB** | Container srsran-gnb | GTP-U para o UPF (N3); tráfego para/do RU/UE (quando UE ativo). |

#### 1.2.2 Validação pós-attach (quando UE estiver ativo)

- **Ping:** UE com sessão PDU ativa faz ping para um destino na DNN (ex. 10.60.0.1 ou internet).
- **iperf3:** servidor na DNN; cliente na UE para medir throughput.
- **traceroute:** da UE para destino na DNN para validar caminho (gNB → UPF → N6).

Comandos típicos (executar **dentro do container UE** ou na UE após obter IP):

```bash
# Assumindo UE com IP 10.60.0.x atribuído pelo SMF/UPF
ping -c 3 10.60.0.1
ping -c 3 8.8.8.8   # se N6 tiver NAT/saída para internet
iperf3 -c <servidor_na_DNN> -t 5
traceroute -n 8.8.8.8
```

#### 1.2.3 Script de framework (placeholder)

O script `scripts/validate-dataplane.sh` (ou equivalente) pode, quando UE estiver presente:

- Verificar sessões PDU nos logs do SMF.
- Verificar túneis GTP-U (por exemplo via `ss`/`tcpdump` na porta 2152).
- Opcional: executar ping/iperf a partir do container UE.

Mesmo sem UE ativo, as capturas N3 (seção 3.2) e os filtros devem estar documentados e prontos.

---

## 2. Diagnóstico Profissional dos Serviços

### 2.1 Diagnóstico de SCTP

#### Comandos por finalidade

| Finalidade | Comando | Interpretação |
|------------|---------|---------------|
| **Listen (SCTP)** | `ss -Slnp \| grep 38412` | AMF em LISTEN SCTP (não use `ss -t`, que é TCP). |
| **Associações** | `ss -Snp state established \| grep 38412` | Pares (AMF, gNB) em ESTABLISHED, se ainda ativos. |
| **No AMF (Docker)** | `docker compose exec -T free5gc-amf ss -Slnp` | Ver SCTP no namespace correto. |

**No host (bridge):**

```bash
sudo ss -Slnp | grep 38412
sudo ss -Snp state established | grep 38412
```

**Módulo kernel SCTP:**

```bash
lsmod | grep sctp
# Esperado: sctp presente. Se não: modprobe sctp (ou kernel sem SCTP).
```

#### Diferenciação de falhas

| Sintoma / Erro | Hipótese | Ação de diagnóstico |
|----------------|----------|----------------------|
| "Network is unreachable" (timeout=0ms) | Rota ou **bind** incorreto no cliente | Definir `bind_addr` no gNB (10.100.200.50). Verificar `ip route get 10.100.200.16` no container gNB. |
| "Connection refused" / "Connection reset" | Ninguém em LISTEN SCTP na porta 38412 ou AMF caiu | `ss -Slnp \| grep 38412` no host ou dentro do container AMF; verificar se o processo AMF está ativo. |
| Timeout longo (ex. 10s) | Firewall descartando ou AMF não respondendo | `iptables -L -n` no host e no container; tcpdump na bridge em 38412. |
| "Invalid argument" / bind falha | Endereço de bind inválido ou já em uso | Verificar que `bind_addr` é um IP do próprio container gNB. |
| Módulo SCTP não carregado | Kernel sem SCTP | `modprobe sctp`; em alguns containers mínimos, garantir que a imagem tem suporte SCTP (libsctp). |

### 2.2 Diagnóstico de Containers

#### Healthcheck funcional

Além de "container up", validar:

- **AMF:** processo `amf` em execução e, se possível, HTTP SBI em 8000 ou resposta do processo.
- **gNB:** processo `gnb` em execução; ausência de restarts contínuos (ExitCode 1 em loop).
- **UPF:** processo `upf` e, quando aplicável, interface `upfgtp` ou equivalente.

Exemplo de verificação no host:

```bash
# Processo ativo
docker compose exec amf pgrep -f amf
docker compose exec srsran-gnb pgrep -f gnb

# Restart count (não deve subir indefinidamente)
docker inspect --format '{{.RestartCount}}' srsran-gnb
```

#### Dependência AMF ↔ gNB

- **Ordem recomendada:** NRF → AMF → depois gNB. No `docker-compose`, gNB pode depender de nada (sobe quando quiser) ou de um serviço "core-ready"; AMF depende do NRF.
- **Restart policy:** gNB com `restart: no` evita loop silencioso; para retry automático após falha N2, usar `restart: on-failure` com backoff (Docker já faz delay entre restarts). Mitigação de flapping: corrigir causa raiz (ex. `bind_addr`) em vez de depender só de restart.

---

## 3. Validação com tcpdump

### 3.1 N2 / NGAP

**Hipótese:** Validar que o handshake SCTP e o NGAP estão presentes entre gNB e AMF.

**Onde capturar:** na interface da bridge Docker (ex. `br-free5gc`) no host, ou no namespace do container (mais invasivo).

**Captura focada em N2:**

```bash
# Host, interface da bridge (ajuste o nome se necessário)
export CAP_N2="captures/n2_$(date +%Y%m%d_%H%M%S).pcap"
sudo tcpdump -i br-free5gc -w "$CAP_N2" -s 0 'sctp and port 38412'
```

**Filtros úteis:**

- `sctp and port 38412` — todo SCTP N2.
- `host 10.100.200.16 and host 10.100.200.50 and port 38412` — restringir aos dois endpoints.

**O que deve aparecer:**

1. **Handshake SCTP:** INIT (gNB→AMF), INIT-ACK (AMF→gNB), COOKIE-ECHO, COOKIE-ACK (associação estabelecida).
2. **NGAP:** payload SCTP com NGAP (PDU tipo NGAP pode ser inspecionado em ferramentas que dissecam NGAP, ou pelo menos tráfego SCTP DATA na porta 38412 após o handshake).

**Análise rápida:**

```bash
tcpdump -r "$CAP_N2" -nn -c 20
# Ou com Wireshark: filtro sctp e depois NGAP (dissector).
```

### 3.2 Plano de Dados (N3 / GTP-U)

**Hipótese:** Validar encapsulamento GTP-U (N3) e, se possível, tráfego desencapsulado em N6.

**Captura N3 (GTP-U UDP 2152):**

```bash
export CAP_N3="captures/n3_$(date +%Y%m%d_%H%M%S).pcap"
sudo tcpdump -i br-free5gc -w "$CAP_N3" -s 0 'udp port 2152'
```

**O que observar:**

- **Túneis TEID:** no Wireshark, coluna "GTP-U" mostra TEID (e direção). Downlink: UPF→gNB (TEID do F-TEID enviado pelo SMF); Uplink: gNB→UPF.
- **Tráfego encapsulado:** pacotes UDP 2152 com payload GTP-U (Echo, G-PDU, etc.). G-PDU carrega o IP do UE.
- **Tráfego desencapsulado (N6):** na interface do UPF voltada para a DNN, IP do pool UE (ex. 10.60.0.0/16) sem encapsulamento GTP.

**Filtros úteis:**

- `udp port 2152` — todo GTP-U.
- `udp port 2152 and host 10.100.200.x` — restringir a um nó (UPF ou gNB).

---

## 4. Checklist de Validação Final

Use este checklist antes de considerar o lab "validado" e pronto para UE.

- [ ] **SCTP (N2):** `ss -Snp state established | grep 38412` (ou dentro do AMF: `docker compose exec -T free5gc-amf ss -Snp state established`) mostra associação **ou**, se vazio, logs AMF com NG Setup confirmam N2 (associação pode ser efêmera).
- [ ] **NG Setup aceito:** logs do AMF contêm aceitação do gNB e resposta NG-Setup; logs do gNB mostram NgSetupRequest enviado sem NGSetupFailure.
- [ ] **AMF registra gNB:** Logs AMF indicam gNB adicionado (ex. "Number of gNBs is now 1").
- [ ] **Logs consistentes:** Sem retries infinitos de NG Setup nem restarts em loop do gNB; sem "Network is unreachable" ou "Failed to connect to AMF".
- [ ] **Capturas coerentes:** tcpdump N2 mostra handshake SCTP e tráfego na 38412; quando houver UE, tcpdump N3 mostra GTP-U na 2152.
- [ ] **Ambiente pronto para UE:** Subscriber no MongoDB; SMF/UPF com DNN e pool de IP configurados; scripts de captura N3 e de teste de dados documentados.

---

## 5. Diferencial — Engenharia avançada

### 5.1 bpftrace / eBPF (opcional)

**Rastrear chamadas SCTP (connect / bind):**

```bash
# Requer bpftrace e permissões adequadas
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_connect { printf("%s %d\n", comm, pid); }'
# Filtrar por processo: /usr/local/bin/gnb ou container PID.
```

**Ideia para latência de handshake:** usar `tracepoint:syscalls:sys_enter_connect` e `sys_exit_connect` com timestamp para estimar tempo até estabelecimento (complementar com tcpdump para precisão).

### 5.2 Métricas sugeridas

- **Tempo até NG Setup completo:** diferença entre primeiro log "Connecting to AMF" e "NG-Setup response" / "CU-CP started successfully" no gNB.
- **Contagem de retries NG Setup:** grep por "Reinitiating NG setup" ou equivalente nos logs; em lab estável deve ser 0 após o primeiro sucesso.
- **RestartCount do container gNB:** `docker inspect --format '{{.RestartCount}}' srsran-gnb`; deve permanecer 0 ou baixo após correções.

### 5.3 Boas práticas de lab reproduzível

- **Versões fixas:** free5GC v3.4.4; srsRAN commit 3ed363dabf (ou tag); imagens Docker com tag explícita.
- **Config em repositório:** `gnb.yml`, `amfcfg.yaml`, `upfcfg.yaml` versionados; uso de `bind_addr` documentado.
- **Scripts versionados:** `scripts/validate-n2-ngap.sh`, `scripts/capture-n2.sh`, `scripts/capture-n3.sh`, `scripts/validate-dataplane.sh` (quando existirem) no repo.
- **Documentação:** este plano (VALIDATION_E2E.md) e README_TROUBLESHOOTING.md referenciando N2/SCTP e bind_addr.
- **Capturas:** diretório `captures/` (ou equivalente) com convenção de nome e README explicando N2 vs N3.

---

## Referência rápida — IPs e portas

| Entidade | IP / alias | Porta relevante |
|----------|------------|------------------|
| AMF | 10.100.200.16 (amf.free5gc.org) | 38412 (SCTP NGAP) |
| gNB | 10.100.200.50 | efêmera (cliente SCTP) |
| UPF | upf.free5gc.org (bridge) | 2152 (GTP-U) |
| Bridge | br-free5gc | — |
