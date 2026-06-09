# Relatório — entrega, estrutura e critérios de avaliação

Este documento orienta **alunos** (o que entregar) e **professores** (como avaliar).

---

## 1. Formato de entrega

- **Formato aceito:** PDF único **ou** arquivo `.zip`/`.7z` com PDF + anexos (logs em `.txt`, PCAPs grandes podem ser omitidos com justificação).
- **Identificação na primeira página:** nome completo, matrícula ou identificação do aluno, turma, data, título “Laboratório free5GC + srsRAN — Interfaces e Protocolos”.
- **Versão do repositório (recomendado):** saída de `git rev-parse --short HEAD` na raiz do clone (se aplicável).

---

## 2. Estrutura sugerida do relatório

1. **Resumo** (10–15 linhas): objetivos, o que foi implementado, principais resultados.
2. **Ambiente:** SO, versões `docker`/`compose`, hardware relevante (RAM, se build srsRAN foi lento).
3. **Roteiro 01 — Core:** referência cruzada com evidências (seção 2 do [01-core-5gc.md](01-core-5gc.md)).
4. **Roteiro 02 — RAN tradicional:** idem ([02-ran-tradicional-n2-n3.md](02-ran-tradicional-n2-n3.md)).
5. **Roteiro 03 — RAN desagregada:** idem ([03-ran-aberta-cu-du.md](03-ran-aberta-cu-du.md)).
6. **Roteiro 05 — RAN aberta O-RAN (Open Fronthaul):** se o curso incluir, idem ([05-ran-open-fronthaul-o-ran.md](05-ran-open-fronthaul-o-ran.md)).
7. **Discussão:**
   - Diferença **integrado vs split** no que respeita a **interfaces standardizadas** (N2, N3, F1).
   - Se fez o Roteiro 05: **Open Fronthaul** (DU–RU) vs **ZMQ** no host; papel da RU emulada.
   - Limitações do laboratório (`ru_dummy`, sem RF real, etc.).
8. **Conclusão** (5–8 linhas).
9. **Anexos** (numerados): A — saídas de comandos; B — logs; C — prints; D — PCAPs (opcional).

**Extensão sugerida:** 8–15 páginas **sem** anexos excessivos (logs podem ser parciais + pasta extra).

---

## 3. Inventário mínimo de evidências (aluno)

| ID | Evidência | Roteiro |
|----|-----------|---------|
| E1 | `docker --version` e `docker compose version` | 01 |
| E2 | `docker compose ps` (core saudável) | 01 |
| E3 | Confirmação rede `free5gc-privnet` / subnet | 01 |
| E4 | Saída `add-subscriber.sh` ou contagem Mongo | 01 |
| E5 | `healthcheck.sh` + `test.sh` (completo) | 01 |
| E6 | Amostra logs NRF + AMF + SMF + UPF | 01 |
| E7 | `docker ps` com `srsran-gnb-tradicional` | 02 |
| E8 | Trecho `gnb.yml` (gnb_id, cell, bind) | 02 |
| E9 | Saída `validate-n2-ngap.sh` | 02 |
| E10 | Logs gNB + AMF (N2/NGAP) | 02 |
| E10a | Captura N2: print Wireshark com SCTP e NGAP | 02 |
| E10b | UE conectado: log srsUE (registro + sessão PDU) e ping com sucesso | 02 |
| E10c | Captura N3: print Wireshark com GTP-U e G-PDU | 02 |
| E11 | `docker ps` com `srsran-cu` e `srsran-du` | 03 |
| E12 | Saídas `ip addr` dentro CU e DU | 03 |
| E13 | Trechos `cu.yml` / `du.yml` relevantes | 03 |
| E14 | Logs CU + DU + `validate-n2-ngap.sh` | 03 |
| E15 | Tabela comparativa tradicional vs desagregada | 03 |
| E16 | `docker ps` com **três** contentores (`srsran-cu`, `srsran-du`, `srsran-ru`) ou justificativa do modo usado | 05 |
| E17 | Saída `validate-n2-ngap.sh` com stack `gNB_open` ativa | 05 |
| E18 | Listagem `gNB_open/logs/` + nota N2/F1/**OFH** | 05 |

Falta **qualquer** evidência marcada como “obrigatória” nos roteiros **que o professor pediu** → desconto na rubrica “Completude”. Os itens **E16–E18** aplicam-se apenas se o Roteiro 05 fizer parte da avaliação.

---

## 4. Prints e capturas de tela

- **Web UI free5GC:** 1 print (estado após login ou página visível).
- **Terminal:** pode ser print **ou** texto copiado com fonte monoespaçada; prefira texto pesquisável para o professor.
- **Wireshark (obrigatório no Roteiro 02):** prints com **filtro visível** — N2: `sctp.port == 38412` (handshake SCTP + NGAP); N3: `udp.port == 2152` (GTP-U e G-PDU).

**Regra:** imagens **legíveis**; se o print for grande, recorte só a região relevante e legende.

---

## 5. Boas práticas com logs

- Não entregar logs de **vários megabytes** no PDF; anexe `.txt` ou mostre só `tail -n 80`.
- **Identifique** no relatório a **data/hora** da coleta e o **container** (`docker logs <nome>`).
- Se algo falhou, inclua o **erro completo** da primeira falha — facilita a defesa oral.

---

## 6. Rubrica sugerida (100 pontos)

| Critério | Peso | Descrição |
|----------|------|-----------|
| **Completude** | 25 | Todos os roteiros pedidos; evidências E1–E15 e E10a–E10c (Roteiro 02) onde aplicável; **E16–E18** se o Roteiro 05 for obrigatório; anexos referenciados no texto. |
| **Correção técnica** | 25 | Comandos coerentes; IPs/interfaces corretos; N2/N3/F1 discutidos sem erros graves. |
| **Análise** | 25 | Tabela comparativa; limitações do lab; ligação aos **objetivos de Interfaces e Protocolos**. |
| **Clareza** | 15 | Estrutura, figuras numeradas, legendas, ortografia aceitável. |
| **Defesa / extra** | 10 | Resposta a perguntas do professor; PCAP; srsUE; troubleshooting documentado. |

---

## 7. Perguntas típicas para defesa oral

1. O que transporta o **N2** em relação ao **N3**?
2. Onde termina o CU-CP e onde começa o DU no split?
3. Por que precisamos de **gnb_id** distintos quando duas RANs compartilham o mesmo AMF?
4. O que mudaria se trocássemos free5GC por outro 5GC (interoperabilidade na interface X)?

---

## 8. Checklist final antes de submeter

- [ ] PDF com identificação completa  
- [ ] Todas as figuras/tabelas numeradas e citadas no texto  
- [ ] Anexos com nomes claros (`anexoA-compose-ps.txt`, …)  
- [ ] Nenhuma senha ou token nos logs  
- [ ] Referências (srsRAN, free5GC, 3GPP TS citados de forma genérica se necessário)
