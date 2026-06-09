# Roteiro 02 — UERANSIM (gNB + UE), N2/N3 e teste E2E

**Objetivos:** ligar o **UERANSIM** (gNB e UE no mesmo *container*) ao AMF Open5GS; validar **N2 (NGAP/SCTP)** e **N3 (GTP-U)**; comprovar **registro** do UE e **sessão PDU** com conectividade à Internet; coletar evidências de plano do usuário (capturas N3/N6 quando possível).

**Pré-requisito:** [Roteiro 01](01-core-open5gs.md) concluído (core ativo, assinante coerente com `ueransim/configs/ue.yaml`).

**Foco:** fluxo SA de ponta a ponta e relação entre interfaces **N2** (controle) e **N3** (dados GTP-U).

**Caminhos:** os comandos assumem a pasta `open5gs-containerized/` na raiz do laboratório (ajuste ao seu clone).

**Apoio em vídeo:** [índice de vídeos](video_seq_report.md) — o [vídeo completo local](https://youtu.be/ic3_CIllb9o) inclui **tcpdump**, **Wireshark** (N2/N3) e testes de conectividade alinhados a este roteiro.

---

## 1. Subida da RAN (UERANSIM)

Com o **core** já em execução (`core/scripts/up_core.sh`):

```bash
cd open5gs-containerized/ueransim
./scripts/up_ran.sh
```

O compose `ueransim/docker-compose.yaml` usa redes **externas** `core_net-n2` e `core_net-n3` criadas pelo compose do **core**. Se aparecer erro de rede não encontrada, volte ao Roteiro 01 e suba o core primeiro.

**Verificação:**

```bash
docker ps --filter name=ueransim --format '{{.Names}} {{.Status}}'
docker exec ueransim ps
```

**Evidência obrigatória:** *print* ou texto de `docker ps` com `ueransim` **Up**.

**Logs (trechos úteis):**

```bash
docker logs ueransim 2>&1 | tail -80
```

Indicadores de sucesso típicos (a redação exata pode variar com a versão):

- **N2:** `NG Setup procedure is successful` (ou mensagem equivalente de *NG Setup* completado).
- **UE:** estado **REGISTERED**, interface `uesimtun0` com IP em `10.60.x.x`.

Avisos de permissões ou temporização são comuns em laboratório; o critério é **registro estável** e **ping** no passo 5.

---

## 2. Identidade do nó RAN e do UE (para o relatório)

Abra e **transcreva ou anexe** (com breve legenda) os campos relevantes de:

- `ueransim/configs/gnb.yaml`: `mcc`, `mnc`, `tac`, `amfConfigs` (endereço e porta do AMF), `gtpIp` (IP N3 do gNB), `ngapIp` / `linkIp` (N2).
- `ueransim/configs/ue.yaml`: `supi`, `mcc`, `mnc`, `gnbSearchList`, `sessions` (APN/DNN).

**Perguntas-guia:**

- Qual o IPv4 do gNB/UERANSIM na **N2**? (no lab padrão: **10.20.0.101**.)  
- Qual o IPv4 do lado GTP-U (N3) no UERANSIM? (padrão: **10.30.0.11**.)  
- Qual o endereço do AMF na N2? (padrão: **10.20.0.11**, porta **38412**.)

**Referência:** [ueransim/docs/RAN.md](../../ueransim/docs/RAN.md).

---

## 3. Validação N2 (NGAP) — logs e verificação ampliada

### 3.1 Logs gNB / AMF

```bash
docker logs ueransim 2>&1 | grep -iE 'ng setup|ngap|amf' | tail -30
docker logs open5gs-amf-containerized 2>&1 | tail -80
```

**Evidência:** trecho em que apareça **NG Setup** bem-sucedido ou aceitação do gNB pelo AMF.

### 3.2 Script de estado do sistema (opcional)

A partir de `core/` (com RAN **já** no ar):

```bash
cd open5gs-containerized/core
./scripts/test-system-status.sh
```

Este script procura correspondências nos logs (ex.: *NG Setup*, PFCP, IP do UE). Anexe a saída se usar.

### 3.3 Captura N2 no host (opcional / avançado)

O projeto não inclui um `capture-n2.sh` dedicado; você pode capturar **SCTP** na porta NGAP no *host* (requer `sudo`):

```bash
sudo tcpdump -i any -nn 'sctp and port 38412'
```

Em outro terminal, **reinicie** o `ueransim` para forçar novo *handshake* (`docker restart ueransim`), aguarde ~15 s, pare o `tcpdump` com Ctrl+C.

**No Wireshark:** filtro `sctp.port == 38412`; expanda **NGAP** para ver `NGSetupRequest` / `NGSetupResponse` se o *dissector* estiver ativo.

**Evidência opcional (se realizar este passo):** *print* com SCTP + NGAP ou anexo `.pcap`.

---

## 4. Validação N3 e N6 — script de captura no UPF

Com **core** e **ueransim** ativos, a partir de `core/`:

```bash
cd open5gs-containerized/core
./scripts/capture-n3-n6-pcaps.sh
```

O script gera *pcaps* sob `core/logs/upf/` (prefixos `n3-gtpu-*.pcap` e `n6-dn-*.pcap`) e dispara *ping* a partir do UE.

**No Wireshark (N3):**

- Filtro sugerido: `udp.port == 2152`  
- Observe **GTP-U** e, com tráfego gerado, **G-PDU** com IP interno do UE.

**Evidência opcional:** *print* do Wireshark com **GTP-U** (porta 2152) ou anexo de `.pcap` + uma frase sobre o papel do TEID.

---

## 5. Teste E2E — conectividade do UE

```bash
cd open5gs-containerized/ueransim
./scripts/test_ue_connection.sh
```

**Evidência obrigatória:** saída **completa** do script (anexo `.txt`).

**Complemento manual:**

```bash
docker exec ueransim ip addr show uesimtun0
docker exec ueransim ping -c 4 -I uesimtun0 8.8.8.8
```

**Evidência:** IP atribuído ao UE e *ping* com perda 0% (ou explicar falhas com trecho de log).

---

## 6. Healthcheck global

Do diretório `core/`:

```bash
cd open5gs-containerized/core
./scripts/healthcheck.sh
```

**Evidência:** saída completa. Com o RAN ativo, as verificações N3 / NG Setup / PFCP devem estar **muito mais alinhadas** do que no Roteiro 01.

---

## 7. Encerramento

Ordem sugerida: **RAN primeiro**, depois **core** (se for desmontar tudo).

```bash
cd open5gs-containerized/ueransim
./scripts/down_ran.sh
```

(O core pode permanecer ativo para novos ensaios.)

---

## Checklist Roteiro 02

- *Container* `ueransim` **Up**; logs com **NG Setup** bem-sucedido (ou equivalente).  
- Parâmetros de `gnb.yaml` e `ue.yaml` descritos no relatório (N2/N3, PLMN, APN).  
- Trechos de log UERANSIM + AMF com N2/NG Setup.  
- (Opcional avançado) Captura SCTP/NGAP no *host* — *print* ou `.pcap`.  
- (Opcional avançado) Captura N3 via `capture-n3-n6-pcaps.sh` — *print* Wireshark ou `.pcap`.  
- Saída de `test_ue_connection.sh` (anexo).  
- Saída de `healthcheck.sh` com RAN ligado.  
- Parágrafo no relatório: diferença **N2** (*controle / NGAP*) vs **N3** (*plano do usuário / GTP-U*).

**Referências:** [ueransim/docs/RAN.md](../../ueransim/docs/RAN.md), [README.md](../../README.md) (*Troubleshooting*).

---

## Resumo de problemas frequentes


| Sintoma                                | Causa provável                         | O que verificar                            |
| -------------------------------------- | -------------------------------------- | ------------------------------------------ |
| `network core_net-n2 not found`        | Core não iniciado                      | `./scripts/up_core.sh` em `core/`.         |
| `slice-not-supported` / falha NG Setup | PLMN, TAC ou SST/SD inconsistentes     | `gnb.yaml` vs `amf.yaml` / slice no UDM.   |
| UE sem IP                              | Assinante em falta ou IMSI ≠ `ue.yaml` | WebUI / Mongo; Roteiro 01.                 |
| Ping falha com IP atribuído            | UPF / rotas / PFCP                     | Logs SMF e UPF; [README](../../README.md). |


