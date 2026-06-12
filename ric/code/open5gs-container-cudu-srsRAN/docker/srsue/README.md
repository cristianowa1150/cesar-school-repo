# srsUE Docker Image (srsRAN 4G, ZMQ, 5G SA)

Imagem Docker para **srsRAN 4G srsUE** em modo 5G SA com ZeroMQ (sem SDR).

## Build

```bash
# Do diretório raiz do projeto
./scripts/build-srsue.sh

# Ou com tag customizada
./scripts/build-srsue.sh srsue:zmq-5g
```

## Uso

O srsUE precisa se conectar ao **srsRAN Project gNB** via ZMQ. O gNB deve estar rodando e acessível.

### Execução standalone

```bash
# Montar config e rodar (privileged para TUN)
docker run --rm -it --privileged \
  -v $(pwd)/configs/srsRAN:/config \
  srsue:latest --ue.phy nr /config/ue.conf
```

### Configuração ZMQ

Em `configs/srsRAN/ue.conf`, ajuste `device_args`:

```ini
# gNB e UE no mesmo host (localhost)
device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6

# gNB em outro container (nome do serviço)
device_args = tx_port=tcp://*:2001,rx_port=tcp://srsran-gnb:2000,id=ue,base_srate=23.04e6
```

- **gNB** envia em `tx_port=2000`, recebe em `rx_port=2001`
- **UE** envia em `tx_port=2001`, recebe em `rx_port=2000`

## Requisitos

- `--privileged` ou `cap_add: [NET_ADMIN]` + `devices: [/dev/net/tun]` (interface TUN)
- Config com IMSI/K/OPc alinhados ao subscriber no Open5GS
- gNB (srsRAN Project) rodando e acessível na porta ZMQ

## Referências

- [s5uishida/build_srsran_4g_zmq_disable_rf_plugins](https://github.com/s5uishida/build_srsran_4g_zmq_disable_rf_plugins)
- [Open5GS 5GC & srsRAN 5G ZMQ Sample Config](https://github.com/s5uishida/open5gs_5gc_srsran_sample_config)
