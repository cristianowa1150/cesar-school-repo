# Open5GS Container CU/DU srsRAN

Laboratorio Docker para testar Open5GS com srsRAN e srsUE via ZMQ.

O projeto tem dois modos de RAN:

- `e2e`: caminho validado, usando `gnb_split_8` da imagem `aetherproject/srsran-gnb:rel-0.7.0` com srsUE.
- `strict-cudu`: caminho experimental para CU e DU em containers separados, usando `srscu` e `srsdu`.

## Decisao Sobre Imagens

A imagem `aetherproject/srsran-gnb:rel-0.7.0` permite o teste E2E com `gnb_split_8` e ZMQ, mas nao e a melhor base para declarar CU e DU como processos/containers independentes.

Para o modo `strict-cudu`, use uma imagem que tenha:

- `srscu`
- `srsdu`
- suporte ZMQ habilitado no build

O projeto inclui uma receita local para criar essa imagem a partir do srsRAN Project:

```bash
./scripts/build-srsran-cudu-zmq.sh
```

Por padrao ela gera:

```bash
SRSRAN_STRICT_CU_DU_IMAGE=open5gs-srsran-cudu-zmq:latest
```

Se voce quiser testar uma imagem OCUDU/Aether equivalente, aponte `SRSRAN_STRICT_CU_DU_IMAGE` no `.env` e rode:

```bash
./scripts/probe-srsran-image.sh "$SRSRAN_STRICT_CU_DU_IMAGE"
```

## Arquitetura

Modo `e2e` validado:

```text
srsUE
  | ZMQ I/Q
srsRAN gnb_split_8
  | N2/N3
Open5GS AMF / UPF-A / UPF-B
  | N6
DN
```

Modo `strict-cudu`:

```text
srsUE
  | ZMQ I/Q
srsRAN DU
  | F1-C 10.80.0.0/24
  | F1-U 10.81.0.0/24
srsRAN CU
  | N2 10.20.0.0/16
  | N3 10.30.0.0/16
Open5GS AMF / UPF-A / UPF-B
```

## Inicio Rapido

```bash
cd code/open5gs-container-cudu-srsRAN

# Uma vez, se a imagem srsue:latest ainda nao existir:
./scripts/build-srsue.sh

./scripts/up_core.sh
./scripts/add-subscriber.sh
./scripts/up_ran.sh
./scripts/test-srsue-e2e.sh
./scripts/down.sh
```

Tambem e possivel subir core e RAN E2E com:

```bash
./scripts/up.sh
```

## CU/DU Estrito

Construa ou selecione uma imagem compativel:

```bash
./scripts/build-srsran-cudu-zmq.sh
./scripts/probe-srsran-image.sh
```

Suba o modo separado:

```bash
./scripts/up_core.sh
./scripts/add-subscriber.sh
./scripts/up_strict_cudu.sh
SRSRAN_PROFILE=strict-cudu ./scripts/test-srsue-e2e.sh
```

## Comandos Uteis

```bash
docker compose --profile e2e ps
docker compose --profile e2e logs -f srsran-cu-du
docker compose --profile e2e logs -f srsran-ue

docker compose --profile strict-cudu ps
docker compose --profile strict-cudu logs -f srsran-cu
docker compose --profile strict-cudu logs -f srsran-du
docker compose --profile strict-cudu logs -f srsran-ue

docker exec srsran-ue-containerized ip addr show tun_srsue
docker exec srsran-ue-containerized ping -c 4 -I tun_srsue 8.8.8.8
```

## Arquivos Relevantes

- `docker-compose.yml`: core Open5GS, RAN split-8, RAN strict CU/DU, srsUE e redes.
- `configs/srsRAN/gnb.yaml`: configuracao do modo E2E `gnb_split_8`.
- `configs/srsRAN/cu.yaml`: N2, N3, F1-C e F1-U do CU separado.
- `configs/srsRAN/du.yaml`: DU separado com radio ZMQ.
- `configs/srsRAN/ue.conf`: srsUE conectado ao peer ZMQ `srsran-du`.
- `docker/srsran-cudu-zmq/Dockerfile`: build local do srsRAN Project com ZMQ.
- `scripts/up_ran.sh`: caminho E2E validado.
- `scripts/up_strict_cudu.sh`: caminho CU/DU separado.
- `scripts/test-srsue-e2e.sh`: validacao de `tun_srsue`, sessao PDU e ping via 5G.
- `scripts/down.sh`: teardown completo, incluindo containers e redes dos perfis `e2e` e `strict-cudu`.

## Observacoes

O lab preserva os arquivos de UERANSIM herdados como referencia e fallback, mas o fluxo principal deste projeto e srsRAN com srsUE.

As chaves de configuracao de split podem variar entre builds do srsRAN Project. Se um binario recusar algum campo, valide a imagem com `probe-srsran-image.sh` e ajuste o YAML correspondente mantendo os mesmos enderecos de rede para facilitar comparacao e captura.
