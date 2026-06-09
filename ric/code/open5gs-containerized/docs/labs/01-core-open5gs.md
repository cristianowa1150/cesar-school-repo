# Roteiro 01 — Infraestrutura e Core 5G (Open5GS)

**Objetivos:** Compreender a stack containerizada do laboratório; levantar o **5GC SA** (Open5GS) **sem RAN**; validar NRF, SCP, AMF, SMF, UPF, MongoDB e dados de assinatura alinhados ao UE.

**Duração indicativa:** 45–60 min (primeira execução, incluindo *pull* de imagens).

**Apoio em vídeo:** [índice de vídeos do lab](video_seq_report.md) (série GCP e [walkthrough completo](https://youtu.be/ic3_CIllb9o) com core + RAN + Wireshark).

---

## 1. Preparação do ambiente

Execute e **guarde a saída** nos anexos do relatório (ou cole em um bloco de código / PDF).

```bash
docker --version
docker compose version
uname -a
```

**Evidência:** *print* ou copiar-colar dos três comandos.

Verifique se o *daemon* Docker está ativo:

```bash
docker info
```

**Evidência:** primeiras 15–20 linhas da saída (sem dados sensíveis).

---

## 2. Limpeza opcional (se repetir o lab)

Só se você já tiver executado o laboratório e quiser estado limpo:

```bash
cd open5gs-containerized/ueransim && ./scripts/down_ran.sh 2>/dev/null || true
cd ../core && ./scripts/down_core.sh
```

Para **apagar volumes MongoDB** (assinantes e base `open5gs` reiniciados — confirme que você não precisa dos dados):

```bash
cd open5gs-containerized/core
docker compose down -v
```

**Evidência:** não obrigatória; mencione no relatório se usou *reset* total com `-v`.

---

## 3. Subida do Core

O script `up_core.sh` pode pedir **`sudo`** para ativar *IP forwarding* no hospedeiro (*host*) — aceite se for política da sua máquina.

```bash
cd open5gs-containerized/core
./scripts/up_core.sh
```

Aguarde o fim do script. Em caso de falha de algum NF, consulte [core/docs/CORE.md](../../core/docs/CORE.md) e a seção *Troubleshooting* do [README](../../README.md).

**Comandos de verificação imediata** (com o *working directory* em `core/`):

```bash
docker compose ps
docker network inspect core_net-sbi --format '{{json .IPAM.Config}}'
docker network inspect core_net-n2 --format '{{json .IPAM.Config}}'
docker network inspect core_net-n3 --format '{{json .IPAM.Config}}'
```

> O prefixo `core_` no nome da rede corresponde ao nome da pasta onde roda o `docker compose` (por padrão, o nome do projeto é o do diretório: `core`).

**Evidências obrigatórias:**

1. **Print ou texto** de `docker compose ps` com os serviços principais **Up** (mongodb, nrf, scp, amf, smf, upf, webui, …).
2. Confirmação das sub-redes esperadas: **SBI** `10.10.0.0/16`, **N2** `10.20.0.0/16`, **N3** `10.30.0.0/16` (comando acima ou `docker network ls | grep core_`).

---

## 4. Assinante (Subscriber)

O **IMSI / SUPI** no núcleo deve coincidir com o definido em `ueransim/configs/ue.yaml` (campo `supi`, por exemplo `imsi-001010000000002`). Caso contrário, o UE não se registra corretamente no Roteiro 02.

**Opção A — WebUI (recomendado):**

- URL: [http://localhost:9999](http://localhost:9999)
- Credenciais padrão: `admin` / `1423` (ver [README](../../README.md) se o volume Mongo já existia e o usuário admin não foi criado).

Utilize **ADD A SUBSCRIBER** com os mesmos parâmetros que o `ue.yaml` e que o exemplo em [README.md](../../README.md) (chave **K**, **OPC**, **AMF**, slice, DNN).

**Se não conseguir login no WebUI** (volume antigo sem *init*):

```bash
cd open5gs-containerized/core
./scripts/add-webui-admin.sh
```

**Opção B — Script (verifique alinhamento com `ue.yaml`):**

```bash
cd open5gs-containerized/core
./scripts/add-subscriber.sh
```

> O script insere um IMSI fixo no código. Se for diferente do `supi` do `ue.yaml`, use a WebUI ou ajuste o arquivo `ue.yaml` / o script para ficarem **iguais**.

**Verificação manual (opcional, para o relatório):**

```bash
docker exec open5gs-mongodb-containerized mongosh open5gs --quiet --eval 'db.subscribers.countDocuments({})'
docker exec open5gs-mongodb-containerized mongosh open5gs --quiet --eval 'db.subscribers.find({}, {imsi:1, supi:1}).limit(3).toArray()'
```

**Evidência:** número de documentos ≥ 1 e eventual campo `imsi` coerente com o UE.

---

## 5. Healthcheck e estado sem RAN

```bash
cd open5gs-containerized/core
./scripts/healthcheck.sh
```

**Evidência:** anexe a saída **completa** (arquivo `.txt` ou PDF).

**Notas:**

- Testes que envolvam `ueransim` (rede N3, NG Setup) podem **falhar ou aparecer em amarelo** enquanto o RAN não estiver no ar — é **esperado** neste roteiro. Explique no relatório: *«validação N2/N3 completa no Roteiro 02»*.
- O *healthcheck* assume *container names* do compose do core (ex.: `open5gs-amf-containerized`).

---

## 6. Web UI

Com o core ativo, abra o WebUI (porta **9999**).

**Evidência:** *print* da página após login ou do painel (sem senhas visíveis).

---

## 7. Logs mínimos a coletar

Para o relatório, guarde **trechos recentes** (últimas ~30–80 linhas) de:

```bash
cd open5gs-containerized/core
docker compose logs --tail 80 nrf
docker compose logs --tail 80 amf
docker compose logs --tail 80 smf
docker compose logs --tail 80 upf
```

(Se o `docker compose` reclamar do serviço, use o nome do serviço definido em `docker-compose.yml`, ex.: `mongodb`, `amf`, `smf`.)

**Evidência:** arquivo `logs-core-amostra.txt` (ou um arquivo por NF) nos anexos.

---

## 8. Encerramento (fim do dia / só core)

```bash
cd open5gs-containerized/core
./scripts/down_core.sh
```

Para também remover volumes: `docker compose down -v` (no diretório `core/`).

---

## Checklist Roteiro 01

- Versões Docker anexadas  
- `docker compose ps` com core saudável  
- Redes `core_net-sbi`, `core_net-n2`, `core_net-n3` identificadas  
- Assinante criado **alinhado ao `ue.yaml`** (WebUI ou script + verificação)  
- `healthcheck.sh` anexado (com nota sobre testes que dependem do RAN)  
- Amostra de logs NRF/AMF/SMF/UPF  
- Texto curto: o que é N2/N3 e por que parte da verificação só faz sentido após o Roteiro 02  

**Referências:** [core/docs/CORE.md](../../core/docs/CORE.md), [README.md](../../README.md).
