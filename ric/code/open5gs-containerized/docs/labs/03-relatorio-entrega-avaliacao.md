# Relatório — entrega, estrutura e critérios de avaliação (Open5GS + UERANSIM)

Este documento orienta **alunos** (o que entregar) e **docentes** (como avaliar).

**Material em vídeo:** [lista de vídeos do laboratório](video_seq_report.md). O [walkthrough completo](https://youtu.be/ic3_CIllb9o) percorre roteiros 01–03 e mostra como fechar evidências (incluindo PCAP / Wireshark) para a entrega.

---

## 1. Formato de entrega

- **Formato aceito:** PDF único **ou** arquivo `.zip`/`.7z` com PDF + anexos (logs em `.txt`; PCAPs grandes podem ser omitidos com justificativa e *hash* ou descrição da captura).
- **Identificação na primeira página:** nome completo, matrícula ou identificação, turma, data, título sugerido: «Laboratório Open5GS + UERANSIM — Interfaces e Protocolos».
- **Versão do repositório (recomendado):** saída de `git rev-parse --short HEAD` na raiz do clone (se aplicável).

---

## 2. Estrutura sugerida do relatório

1. **Resumo** (10–15 linhas): objetivos, o que foi executado, principais resultados.
2. **Ambiente:** SO, versões `docker` / `docker compose`, RAM relevante (*pull* de imagens).
3. **Roteiro 01 — Core:** referência cruzada com evidências ([01-core-open5gs.md](01-core-open5gs.md)).
4. **Roteiro 02 — UERANSIM:** idem ([02-ueransim-n2-n3-e2e.md](02-ueransim-n2-n3-e2e.md)).
5. **Discussão:**
  - Papel das interfaces **N2** (NGAP/SCTP) e **N3** (GTP-U) no cenário containerizado.
  - Diferenças em relação a um gNB monolítico *vs.* *split* CU/DU (referência conceitual; este laboratório usa UERANSIM integrado).
  - Limitações (*emulation*, sem RF real, *stub* de célula, etc.).
6. **Conclusão** (5–8 linhas).
7. **Anexos** (numerados): A — saídas de comandos; B — logs; C — *prints*; D — PCAPs.

**Extensão sugerida:** 8–15 páginas **sem** anexos excessivos.

---

## 3. Inventário mínimo de evidências (aluno)


| ID  | Evidência                                                                   | Roteiro |
| --- | --------------------------------------------------------------------------- | ------- |
| E1  | `docker --version` e `docker compose version`                               | 01      |
| E2  | `docker compose ps` (core saudável)                                         | 01      |
| E3  | Confirmação redes `core_net-sbi` / `core_net-n2` / `core_net-n3` e subnets  | 01      |
| E4  | Assinante criado (WebUI, script ou `mongosh`) alinhado ao `ue.yaml`         | 01      |
| E5  | Saída completa `healthcheck.sh` (sem RAN ou com nota sobre limitações)      | 01      |
| E6  | Amostra logs NRF + AMF + SMF + UPF                                          | 01      |
| E7  | `docker ps` com `ueransim` **Up**                                           | 02      |
| E8  | Trechos relevantes `gnb.yaml` / `ue.yaml`                                   | 02      |
| E9  | Logs UERANSIM + AMF com N2 / NG Setup                                       | 02      |
| E10 | (Opcional avançado) PCAP ou *print* Wireshark N2 (`sctp.port == 38412`)     | 02      |
| E11 | (Opcional avançado) PCAP N3 ou *print* Wireshark GTP-U (`udp.port == 2152`) | 02      |
| E12 | Saída completa `test_ue_connection.sh`                                      | 02      |
| E13 | `healthcheck.sh` com RAN ligado                                             | 02      |


Falta **evidência obrigatória** marcada nos roteiros → desconto na rubrica «Completude».

---

## 4. Prints e capturas de tela

- **WebUI Open5GS:** 1 *print* (após login ou tela visível, sem senha).
- **Terminal:** *print* ou texto monoespaçado; texto pesquisável é preferível.
- **Wireshark:** *prints* com **filtro visível** — N2: `sctp.port == 38412`; N3: `udp.port == 2152`.

**Regra:** imagens **legíveis**; recortes legendados.

---

## 5. Boas práticas com logs

- Não entregar logs de vários megabytes no PDF; anexe `.txt` ou use `tail -n 80`.
- Indique **data/hora** da coleta e o **container** (`docker logs <nome>`).
- Em falhas, inclua a **primeira** mensagem de erro completa.

---

## 6. Rubrica sugerida (100 pontos)


| Critério             | Peso | Descrição                                                                    |
| -------------------- | ---- | ---------------------------------------------------------------------------- |
| **Completude**       | 25   | Roteiros 01 e 02; evidências E1–E13 onde aplicável; anexos citados no texto. |
| **Correção técnica** | 30   | Comandos e IPs coerentes com o projeto; N2/N3 discutidos sem erros graves.   |
| **Análise**          | 25   | Limitações do lab; ligação a **interfaces e protocolos** 5G SA.              |
| **Clareza**          | 15   | Estrutura, figuras numeradas, ortografia aceitável.                          |
| **Defesa / extra**   | 5    | PCAP N2 opcional; *troubleshooting* documentado; respostas na defesa.        |


---

## 7. Perguntas para discussão

1. O que transporta o **N2** em relação ao **N3**?
2. Por que o compose UERANSIM depende de redes externas `core_net-n2` e `core_net-n3`?
3. O que é **PFCP** no cruzamento SMF–UPF e como se relaciona com a sessão PDU?
4. O que mudaria se o IMSI no núcleo não correspondesse ao `supi` do `ue.yaml`?

---

## 8. Checklist final antes de submeter

- PDF com identificação completa  
- Figuras/tabelas numeradas e citadas  
- Anexos com nomes claros (`anexoA-compose-ps.txt`, …)  
- Nenhuma senha ou *token* nos logs  
- Referências (Open5GS, UERANSIM, 3GPP, quando aplicável)

