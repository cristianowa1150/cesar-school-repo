# Lab Open5GS + srsRAN CU/DU + srsUE

Este documento registra os principais pontos do laboratorio
`open5gs-container-cudu-srsRAN`.

## Estado Validado

O caminho validado de ponta a ponta usa:

- Open5GS como 5GC.
- `aetherproject/srsran-gnb:rel-0.7.0` executando `gnb_split_8`.
- `srsue:latest` via radio virtual ZMQ.
- Subscriber padrao `001010000000003`.
- DNN `internet`.
- Pool UE `10.60.0.0/16`.

Validacao realizada:

- `tun_srsue` criada no container `srsran-ue-containerized`.
- IP de sessao PDU: `10.60.0.2`.
- Ping via plano de dados 5G:

```bash
docker exec srsran-ue-containerized ping -c 4 -I tun_srsue 8.8.8.8
```

Resultado esperado: `0% packet loss`.

## Modos de RAN

### Modo `e2e`

Modo principal e validado.

```text
srsUE
  | ZMQ I/Q
srsRAN gnb_split_8
  | N2: 10.20.0.101 -> AMF 10.20.0.11
  | N3: 10.30.0.101 -> UPF
Open5GS
```

Comandos:

```bash
./scripts/up.sh
./scripts/test-srsue-e2e.sh
./scripts/down.sh
```

Ou em etapas:

```bash
./scripts/up_core.sh
./scripts/add-subscriber.sh
./scripts/up_ran.sh
./scripts/test-srsue-e2e.sh
```

### Modo `strict-cudu`

Modo experimental para CU e DU em containers/processos separados.

```text
srsUE
  | ZMQ I/Q
srsRAN DU
  | F1-C/F1-U
srsRAN CU
  | N2/N3
Open5GS
```

Ele exige uma imagem com:

- `srscu`
- `srsdu`
- suporte ZMQ habilitado

O projeto inclui uma receita local:

```bash
./scripts/build-srsran-cudu-zmq.sh
./scripts/probe-srsran-image.sh
./scripts/up_strict_cudu.sh
SRSRAN_PROFILE=strict-cudu ./scripts/test-srsue-e2e.sh
```

## Sobre as Imagens

A imagem `aetherproject/srsran-gnb:rel-0.7.0` funciona para o modo `e2e`
com `gnb_split_8` e ZMQ.

Ela nao deve ser tratada como garantia de CU e DU em containers separados.
Para o modo separado, use `SRSRAN_STRICT_CU_DU_IMAGE`, por padrao:

```bash
open5gs-srsran-cudu-zmq:latest
```

Essa imagem e criada a partir do srsRAN Project com ZMQ habilitado.

## Redes e Enderecos Principais

| Rede | Uso | Enderecos principais |
| --- | --- | --- |
| `net-sbi` | SBI Open5GS | NRF `10.10.0.10`, AMF `10.10.0.11`, SMF `10.10.0.12` |
| `net-n2` | NGAP gNB/CU -> AMF | AMF `10.20.0.11`, `gnb_split_8` `10.20.0.101`, CU estrito `10.20.0.110` |
| `net-n3` | GTP-U gNB/CU -> UPF | `gnb_split_8` `10.30.0.101`, UPF-A `10.30.0.21`, UPF-B `10.30.0.22` |
| `net-n4` | PFCP SMF -> UPF | SMF `10.40.0.12`, UPF-A `10.40.0.21`, UPF-B `10.40.0.22` |
| `net-n6` | UPF -> DN | DN `10.50.0.100` |
| `net-zmq` | radio virtual | gNB/DU `172.31.250.10`, srsUE `172.31.250.20` |
| `net-f1c` | CU/DU estrito F1-C | CU `10.80.0.10`, DU `10.80.0.30` |
| `net-f1u` | CU/DU estrito F1-U | CU `10.81.0.10`, DU `10.81.0.30` |

## Healthcheck

O `healthcheck.sh` deve ser interpretado como diagnostico do lab ativo.

O falso alarme observado tinha duas causas:

1. O teste N2 ainda apontava para `10.20.0.110`, que e o IP do CU no modo
   `strict-cudu`. No modo `e2e`, o IP correto da RAN e `10.20.0.101`.
2. A checagem de celula procurava mensagens antigas como `Selected cell`.
   Neste lab com srsUE, a evidencia correta pode ser `RRC Connected`,
   `PDU Session Establishment successful` ou a propria presenca de
   `tun_srsue` com IP `10.60.x.x`.

Criterios fortes de sucesso:

```bash
docker compose --profile e2e ps
docker exec srsran-ue-containerized ip -4 addr show tun_srsue
docker exec srsran-ue-containerized ping -c 4 -I tun_srsue 8.8.8.8
```

## Troubleshooting Rapido

### UE sem `tun_srsue`

Verifique:

```bash
docker compose --profile e2e logs --tail 120 srsran-ue
docker compose --profile e2e logs --tail 120 srsran-cu-du
docker compose logs --tail 120 amf smf
```

Se o AMF indicar `Unknown UE by SUCI`, reprovisione:

```bash
./scripts/add-subscriber.sh
docker compose --profile e2e up -d --force-recreate srsran-ue
```

### RAN para logo apos iniciar

Os binarios srsRAN sao interativos. O Compose usa `stdin_open: true` e
`tty: true` nos containers RAN/UE para evitar encerramento por EOF.

### Estado residual de containers ou redes

Use:

```bash
./scripts/down.sh
docker ps --format '{{.Names}}' | grep -E 'open5gs|srsran|ueransim'
```

O `down.sh` remove containers e redes dos perfis `e2e`, `strict-cudu` e
`tools`, alem de sobras conhecidas do projeto original.

## Scripts Principais

| Script | Funcao |
| --- | --- |
| `scripts/up.sh` | Sobe core e RAN E2E validada |
| `scripts/up_core.sh` | Sobe somente Open5GS |
| `scripts/up_ran.sh` | Garante subscriber e sobe `gnb_split_8` + srsUE |
| `scripts/up_strict_cudu.sh` | Sobe CU/DU separados, se a imagem for compativel |
| `scripts/test-srsue-e2e.sh` | Valida TUN, PDU e ping via 5G |
| `scripts/healthcheck.sh` | Diagnostico rapido do lab ativo |
| `scripts/test-system-status.sh` | Diagnostico detalhado |
| `scripts/down.sh` | Teardown completo |

