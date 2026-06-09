# Série em vídeo — execução do laboratório Open5GS + UERANSIM

Esta página reúne os vídeos de apoio ao lab. Há **dois formatos**:


| Formato                             | Público-alvo                                                                                                                        | Conteúdo                                                                                                 |
| ----------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| **Série curta (1–3)** abaixo        | Quem monta o ambiente no **GCP** em etapas                                                                                          | VM, Docker, subida E2E resumida.                                                                         |
| **Vídeo único — laboratório local** | Quem executa em **Linux local** (ou VM já pronta) e quer ver **tudo de uma vez**, incluindo **Wireshark** e **ferramentas de rede** | Equivalente aos roteiros escritos **01 → 02 → 03** (core, UERANSIM/capturas, fechamento para relatório). |


Os `.md` continuam sendo a referência para comandos exatos, evidências e rubrica; os vídeos mostram o fluxo na prática.

---

## Como usar esta sequência

1. **Trilha GCP:** assista os episódios **1 → 2 → 3** na ordem (cada etapa pressupõe a anterior).
2. **Trilha local completa:** use o [vídeo completo](#video-lab-completo-local) como visão integrada; volte aos roteiros 01–03 para copiar comandos e montar anexos.
3. Tenha o repositório clonado e os roteiros abertos em outra aba.
4. Pause e reproduza os mesmos comandos no seu terminal (se possível) — o objetivo não é só “ver”, e sim **replicar** e registrar evidências para o [relatório de entrega](03-relatorio-entrega-avaliacao.md).

---

## Episódios


| #     | Tema                             | O que você deve conseguir ao final                                                                                                              | Roteiro escrito relacionado                                                                                                  |
| ----- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| **1** | **VM no GCP**                    | Criar/acessar uma VM adequada ao lab (SSH, recursos, noção de firewall).                                                                        | [Pré-lab — GCP, SSH e ponte ao código](00-pre-lab-gcp-vm-e-acesso.md)                                                        |
| **2** | **Docker na VM**                 | Instalar Docker e Docker Compose v2; `docker run hello-world` (ou equivalente) funcionando.                                                     | [Instalação Docker — Ubuntu](00-docker-instalacao-ubuntu.md)                                                                 |
| **3** | **Sistema 5G ponta a ponta**     | Subir core + RAN, assinante coerente com o UE, checagens de saúde e noção de N2/N3/E2E.                                                         | [Roteiro 01 — Core](01-core-open5gs.md) · [Roteiro 02 — UERANSIM / E2E](02-ueransim-n2-n3-e2e.md)                            |
| **★** | **Laboratório completo (local)** | Percorrer **roteiros 01 a 03** em uma sessão; **tcpdump** / **Wireshark** (N2/N3); `ping` / rotas / `docker`; fechamento alinhado ao relatório. | [01](01-core-open5gs.md) · [02](02-ueransim-n2-n3-e2e.md) · [03 — Relatório e evidências](03-relatorio-entrega-avaliacao.md) |


### 1) VM no GCP (`setup_vm_gcp`)

**Vídeo:** [youtu.be/67Xey5GV1G4](https://youtu.be/67Xey5GV1G4)

Ideal para quem ainda não tem a máquina do laboratório. Preste atenção em **zona**, **tamanho da VM** (CPU/RAM/disco) e **como abrir o terminal** (SSH no navegador vs `gcloud`), alinhado ao pré-lab.

---

### 2) Instalação do Docker (`installing_docker_gcp`)

**Vídeo:** [youtu.be/76TMQdSAXSw](https://youtu.be/76TMQdSAXSw)

Foca no ambiente Ubuntu da VM. Confirme no seu terminal:

```bash
docker --version
docker compose version
```

Se algo falhar aqui, resolva **antes** de subir o Open5GS.

---

### 3) Sistema 5G E2E (`running_5G_system_e2e`)

**Vídeo:** [youtu.be/dgGzGDYYE_c](https://youtu.be/dgGzGDYYE_c)

Cobre o fluxo completo (core, assinante, UERANSIM, verificações). Ao assistir, compare com:

- ordem **core → assinante → RAN** nos roteiros 01 e 02;
- necessidade de o **IMSI no MongoDB** coincidir com o `supi` em `ueransim/configs/ue.yaml`;
- scripts `core/scripts/up_core.sh`, `core/scripts/add-subscriber.sh` (ou equivalente), `ueransim/scripts/up_ran.sh` e `core/scripts/healthcheck.sh`.

---

### ★) Laboratório completo — local (`full_lab_local_wireshark`)

**Vídeo:** [youtu.be/ic3_CIllb9o](https://youtu.be/ic3_CIllb9o)

Mesmo conteúdo descrito na [seção detalhada abaixo](#video-lab-completo-local); use como referência única se preferir uma única sessão gravada (Linux local ou VM já com Docker).

---



## Vídeo completo — execução local (roteiros 01 a 03, Wireshark e rede)

Gravação **única** em ambiente **local** (máquina Linux ou VM com Docker já utilizável), percorrendo o mesmo conteúdo dos roteiros escritos **do início ao fechamento para entrega**, com ênfase em **visibilidade de protocolo** e **comandos de rede**.

**Vídeo:** [Laboratório completo — roteiros 01 a 03 (Wireshark e rede)](https://youtu.be/ic3_CIllb9o)

### O que o vídeo cobre (mapa rápido)


| Fase                     | Roteiro escrito                                                        | Tópicos típicos no vídeo                                                                                                                                                                                                                                                  |
| ------------------------ | ---------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **01 — Core**            | [01-core-open5gs.md](01-core-open5gs.md)                               | Limpeza opcional, `up_core`, MongoDB / assinante alinhado ao `ue.yaml`, WebUI, `healthcheck.sh`, conectividade básica entre containers.                                                                                                                                   |
| **02 — UERANSIM e rede** | [02-ueransim-n2-n3-e2e.md](02-ueransim-n2-n3-e2e.md)                   | `up_ran`, logs do `ueransim`, **captura no host** com `tcpdump` (ex.: SCTP **38412** para N2, UDP **2152** para GTP-U / N3), abertura dos PCAPs no **Wireshark** com filtros `sctp.port == 38412` e `udp.port == 2152`, testes com `ping` / rotas quando o roteiro pedir. |
| **03 — Relatório**       | [03-relatorio-entrega-avaliacao.md](03-relatorio-entrega-avaliacao.md) | Como relacionar *prints*, logs e PCAPs às evidências **E1–E11**; estrutura sugerida do PDF; o que conta como anexo mínimo.                                                                                                                                                |


### Ferramentas que costumam aparecer

- **Docker / Compose** — subida do core e da RAN, `docker ps`, `docker logs`, `docker exec` (ex.: `ip addr`, `ping` a partir do UE/container).
- **tcpdump** no *host* — interfaces `docker0`, `br-`* ou `any`, conforme [roteiro 02](02-ueransim-n2-n3-e2e.md) (NGAP em SCTP, GTP-U).
- **Wireshark** — dissecção NGAP em N2 e GTP-U em N3; *prints* com **filtro visível** para o relatório ([critérios no roteiro 03](03-relatorio-entrega-avaliacao.md)).
- **Scripts do repositório** — `healthcheck.sh`, `test-system-status.sh`, `test_ue_connection.sh` (quando aplicável ao seu clone).

### Diferença em relação aos episódios 1–3 (GCP)

A série **1–3** acima foca em **criar a VM no GCP** e instalar Docker. O **vídeo completo local** assume que o SO e o Docker já estão ok e aprofunda **roteiros 01–03**, **capturas** e **entrega** — útil para quem labora no próprio notebook ou já tem VM provisionada.

---

## Mini checklist (depois da série)

Marque mentalmente (ou no relatório) o que já está válido no **seu** ambiente:

- VM GCP acessível por SSH e com recursos suficientes para Docker + várias imagens.
- `docker` e `docker compose` funcionando sem erro.
- Core Open5GS em execução e NFs saudáveis (conforme roteiro 01 / `healthcheck.sh`).
- Assinante cadastrado e **alinhado** ao `ue.yaml`.
- UERANSIM ativo, NG setup e, quando aplicável, interface `uesimtun0` / IP de dados conforme roteiro 02.
- *(Se seguiu o vídeo completo local)* PCAP ou *print* Wireshark com N2 e/ou N3 alinhados ao [roteiro 02](02-ueransim-n2-n3-e2e.md) e à rubrica do [roteiro 03](03-relatorio-entrega-avaliacao.md).

---

**Índice geral dos labs:** [INDICE.md](INDICE.md).