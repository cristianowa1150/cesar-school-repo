# RAN tradicional (gNB monolítico)

Um container `srsran-gnb-tradicional` na rede `free5gc-privnet`, IP **10.100.200.50**.

## Uso

```bash
# Com o core já ativo (../core/scripts/up.sh)
./scripts/up.sh
./scripts/down.sh
```

Configuração padrão: `configs/gnb-zmq-srsue.yml` (ZMQ para srsUE no host). Para ru_dummy (apenas N2, sem UE): `GNB_CONFIG=gnb.yml ./scripts/up.sh`. Build: contexto `../core` + `Dockerfile.srsRAN`.
