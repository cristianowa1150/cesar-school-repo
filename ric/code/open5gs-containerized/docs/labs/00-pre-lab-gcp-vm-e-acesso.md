# Pré-lab — VM no GCP, acesso SSH e Docker (gravação / demonstração)

Este roteiro cobre **criação da máquina virtual no Google Cloud**, **duas formas de acesso por terminal** e **ponte para o código do lab**. A **instalação do Docker** está no roteiro dedicado [Instalação Docker — Ubuntu](00-docker-instalacao-ubuntu.md).

**Público:** quem vai **gravar um vídeo** ou conduzir o lab pela primeira vez no GCP.

**Não confundir com o Cloud Shell (`>_` no topo do Console):** o laboratório Open5GS + UERANSIM exige uma **VM dedicada** com Docker; o Cloud Shell não é o ambiente recomendado para este stack.

---

## 1. Duas opções viáveis de acesso ao shell da VM


| Opção                                   | O que é                                                                                                                      | Quando usar no vídeo                                                                                                                                                                   |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **A — SSH no navegador**                | No Console GCP → Compute Engine → VM → botão **SSH**: abre um terminal no browser ligado à VM.                               | **Trilha mínima:** não exige instalar nada no PC nem `gcloud`; ideal para iniciantes.                                                                                                  |
| **B — `gcloud compute ssh` (opcional)** | Terminal local com [Google Cloud SDK](https://cloud.google.com/sdk/docs/install), `gcloud auth login` e projeto configurado. | Quem já usa `gcloud` e prefere janela de terminal local (fonte, *copy-paste*). **Não é obrigatório** para concluir o lab se você seguir a Opção A e uma das formas da seção 7 sem SDK. |


Em ambos os casos você está num shell **dentro da VM**; a diferença é só o **cliente** (browser vs `gcloud`).

---

## 2. Pré-requisitos no GCP (antes de criar a VM)

1. Conta Google com **faturamento** ativo no projeto (Compute Engine cobra pela VM em execução).
2. Projeto GCP criado; anote o **ID do projeto** (ex.: `meu-projeto-lab`).
3. API **Compute Engine** habilitada (o Console costuma oferecer “Ativar” na primeira vez que você abre Compute Engine).

**Dica para demonstração:** use um projeto de laboratório e **encerre ou exclua a VM** ao terminar para evitar custo contínuo.

---

## 3. Criar a VM (configuração sugerida)

No Console: **Compute Engine → Instâncias de VM → Criar instância**.

Sugestão alinhada aos labs (Docker, várias imagens, core + UERANSIM):


| Campo                   | Valor sugerido                                                                                                                                                                         |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nome                    | Ex.: `lab-open5gs`                                                                                                                                                                     |
| Região / zona           | Escolha uma zona próxima (ex.: `southamerica-east1-a`); se usar `gcloud` depois, mantenha a **mesma zona** nos comandos.                                                               |
| Série / tipo de máquina | **E2** ou **N2**, **4 vCPU**, **8–16 GiB** de memória (16 GiB reduz risco de falha no *pull* / *compose*).                                                                             |
| SO                      | **Ubuntu 22.04 LTS** ou **24.04 LTS** (x86_64).                                                                                                                                        |
| Disco de inicialização  | **50–80 GB** balanceado ou SSD (imagens Docker ocupam bastante espaço).                                                                                                                |
| Firewall                | **Permitir HTTP/HTTPS** é opcional. Para abrir a WebUI pela **internet sem `gcloud`** (seção 7.1), você criará uma **regra de firewall** só para a porta **9999** (e etiquetas na VM). |


Crie a instância e aguarde o estado **Em execução**.

**ARM (opcional, comparação arquitetura):** famílias como **T2A** usam `aarch64`. Antes de gravar, valide se todas as imagens do `docker compose` sobem sem emulação; caso contrário, mantenha a VM **x86_64** como roteiro principal.

---

## 4. Opção A — Abrir terminal via SSH no navegador

1. **Compute Engine → Instâncias de VM**.
2. Na linha da VM, clique em **SSH** (ou **Conectar** → SSH no navegador).
3. Uma janela/aba abre com terminal já autenticado.

**Primeira conexão:** pode haver atraso enquanto as chaves são configuradas.

---

## 5. Opção B — Terminal local com `gcloud compute ssh` (opcional)

1. Instale o [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) e execute:

```bash
gcloud auth login
gcloud config set project SEU_PROJECT_ID
```

1. Conecte (substitua `NOME_DA_VM` e `ZONA`):

```bash
gcloud compute ssh NOME_DA_VM --zone=ZONA
```

1. Na primeira vez, confirme a impressão digital do host se o `gcloud` perguntar.

A partir daqui os comandos são **idênticos** aos da Opção A (tudo roda na VM).

---

## 6. Na VM — Docker Engine e Compose v2

Execute **na VM** o roteiro completo: **[00 — Instalação Docker (Ubuntu)](00-docker-instalacao-ubuntu.md)** (repositório oficial via `apt`, grupo `docker`, verificação e teste opcional `hello-world`).

Depois, confira rapidamente (útil no vídeo e no relatório do Roteiro 01):

```bash
docker --version
docker compose version
uname -a
```

---

## 7. WebUI na porta 9999 — sem exigir `gcloud` no laptop

Na VM, o WebUI do lab responde em `http://127.0.0.1:9999`. O **SSH no navegador** não abre um navegador gráfico dentro da VM; para ver a interface no **seu computador**, use uma das opções abaixo. Combinando **Opção A** (SSH no navegador) com **7.1, 7.2 ou 7.3**, você cobre o lab usando só Console GCP e terminal no browser, **sem** instalar o Google Cloud SDK no laptop.

### 7.1 Regra de firewall + IP externo (tudo pelo Console GCP)

Indicado para **demo em sala** ou gravação, desde que você aceite expor a porta (mitigue com origem restrita ou VM temporária).

1. Anote o **IP externo** da VM (Compute Engine → instâncias).
2. **VPC network → Firewall → Create firewall rule:**
  - **Targets:** “Specified target tags”; tag exemplo: `open5gs-webui`.
  - Na **instância**, em “Editar” → **Tags de rede**, adicione a mesma tag (`open5gs-webui`).
  - **Source IP ranges:** em laboratório fechado pode ser o seu IP (`x.x.x.x/32`); **não** use `0.0.0.0/0` em produção (qualquer um na internet acessaria a WebUI).
  - **Protocols and ports:** TCP **9999**.
3. Com o core no ar, no navegador do laptop: `http://IP_EXTERNO:9999`.

**Segurança:** credenciais padrão da WebUI são conhecidas; trate a VM como **descartável** e derrube a regra ou a VM após o lab.

### 7.2 Túnel HTTPS a partir da VM (sem abrir porta na VPC)

Ainda no SSH do navegador, na VM, você pode publicar `localhost:9999` por um serviço de túnel (ex.: [Cloudflare Tunnel (*quick tunnel*)](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/do-more-with-tunnels/trycloudflare/) ou [ngrok](https://ngrok.com/)). O provedor devolve uma **URL HTTPS**; abra-a no laptop — **não** é necessário `gcloud` nem regra de firewall para a 9999.

- Leia os termos e limites do serviço; em aula, prefira 7.1 com IP restrito ou VM só para o lab.

### 7.3 Sem WebUI no vídeo — só terminal

O Roteiro 01 aceita criar o assinante com `**./scripts/add-subscriber.sh`** (alinhado ao `ue.yaml`). Nada impede concluir evidências sem abrir o navegador; cite no relatório que usou a opção por script.

### 7.4 Opcional — encaminhamento local com `gcloud` (quem já usa SDK)

Se você instalou o Cloud SDK e prefere não expor a 9999 na internet:

```bash
gcloud compute ssh NOME_DA_VM --zone=ZONA -- -L 9999:127.0.0.1:9999 -N
```

Mantenha essa sessão aberta; em outro terminal, `gcloud compute ssh` sem `-N` para comandos. No laptop: `http://localhost:9999`.

### 7.5 Avançado — SSH local com `-L` (sem subcomando `gcloud ssh`)

Se você configurar **chave SSH** no metadata da VM ou OS Login e conectar com `ssh usuário@IP_EXTERNO`, pode usar:

```bash
ssh -L 9999:127.0.0.1:9999 usuario@IP_EXTERNO
```

(Detalhes de usuário e chave dependem da imagem Ubuntu da GCP; a Opção A do Console costuma ser mais simples.)

**Túnel SSH reverso** (`ssh -R`) só é prático se existir um servidor SSH **alcançável na internet** ou VPN (ex.: outra VM fixa); por isso não é a rota principal deste roteiro.

---

## 8. Obter o código do laboratório na VM

Exemplo com `git` (ajuste a URL ao repositório oficial da disciplina):

```bash
sudo apt-get update
sudo apt-get install -y git
cd ~
git clone https://github.com/jakunzler/cesar-school-repo.git
cd cesar-school-repo/oran/code/open5gs-containerized
```

Confira se a pasta `core/` e `ueransim/` existem e que os scripts têm permissão de execução (`chmod +x` nos `.sh` se necessário).

---

## 9. Roteiro do vídeo (sugestão de ordem)

1. Console GCP: projeto, criar VM, **SSH no navegador** (Opção A) em 30–60 s.
2. **Trilha sem `gcloud`:** permaneça no SSH do navegador para Docker, clone e comandos dos roteiros 01/02; para WebUI use **7.1** (firewall + IP) ou **7.2** (túnel na VM) ou **7.3** (só `add-subscriber.sh`). **Trilha com SDK:** opcionalmente mostre `gcloud compute ssh` (Opção B) para o bloco longo de comandos.
3. `docker --version`, `docker compose version`, `uname -a`.
4. Seguir [01-core-open5gs.md](01-core-open5gs.md) até core estável + assinante + WebUI **ou** script de assinante (conforme seção 7).
5. Seguir [02-ueransim-n2-n3-e2e.md](02-ueransim-n2-n3-e2e.md) com core já no ar.
6. Mencionar [03-relatorio-entrega-avaliacao.md](03-relatorio-entrega-avaliacao.md) como documento de **entrega** (não como passo de execução na VM).

---

## 10. Depois do ambiente pronto — o que seguir?

- **Sim:** com Docker instalado e repositório clonado na VM, você segue o **Roteiro 01** (core) e em seguida o **Roteiro 02** (UERANSIM), na ordem dos arquivos [01-core-open5gs.md](01-core-open5gs.md) e [02-ueransim-n2-n3-e2e.md](02-ueransim-n2-n3-e2e.md).
- O arquivo **[03 — Relatório, entrega e avaliação](03-relatorio-entrega-avaliacao.md)** não é um terceiro “passo de laboratório” no terminal: ele descreve **o que entregar** (PDF/anexos) e critérios. Fluxo típico: **00 (este doc, uma vez) → 01 → 02 → elaboração do relatório conforme 03**.

---

## Checklist rápido (docente / gravador)

- VM Ubuntu x86_64, RAM e disco suficientes.
- SSH testado (navegador; `gcloud` só se for usar Opção B).
- Docker + Compose v2 funcionando sem sudo.
- Clone do repo no caminho esperado pelos roteiros 01/02.
- Plano para WebUI: firewall **9999** (7.1), túnel na VM (7.2), `add-subscriber.sh` (7.3) ou `-L` com `gcloud`/`ssh` (7.4–7.5).
- Plano para desligar ou excluir a VM após a gravação.

**Referências:** [INDICE.md](INDICE.md), [README.md](../../README.md).