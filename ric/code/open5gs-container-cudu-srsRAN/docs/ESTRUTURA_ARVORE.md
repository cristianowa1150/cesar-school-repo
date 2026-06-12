# Árvore de Diretórios Proposta - 5G SA Open5GS + srsRAN/UERANSIM

```
open5gs-container-srsRAN/
├── configs/
│   ├── open5gs/              # Configurações Open5GS 5GC
│   │   ├── amf.yaml          # AMF - NGAP (N2), TAC, PLMN, S-NSSAI
│   │   ├── ausf.yaml
│   │   ├── nrf.yaml
│   │   ├── nssf.yaml
│   │   ├── pcf.yaml
│   │   ├── scp.yaml
│   │   ├── smf.yaml          # SMF - PFCP, GTP-C/U, DNN, subnet UE
│   │   ├── udm.yaml
│   │   ├── udr.yaml
│   │   ├── upf-a.yaml        # UPF - N3 (GTP-U), N4 (PFCP), N6 (DN)
│   │   ├── upf-b.yaml
│   │   ├── freeDiameter/
│   │   │   └── smf.conf
│   │   ├── hnet/             # Chaves HNET
│   │   └── tls/              # Certificados TLS
│   │
│   ├── srsRAN/               # Configurações srsRAN (gNB + UE ZMQ)
│   │   ├── gnb.yaml          # srsRAN Project gNB - N2, N3, ZMQ
│   │   ├── ue.conf           # srsRAN 4G srsUE - ZMQ, USIM, APN
│   │   └── rr.conf           # (opcional) Radio Resources para srsENB 4G
│   │
│   └── ueransim/             # Configurações UERANSIM (alternativa)
│       ├── gnb.yaml
│       └── ue.yaml
│
├── overrides/
│   ├── ueransim-ifaces.override.yml   # IPs N2/N3 para UERANSIM
│   └── srsran.override.yml            # (opcional) Override para srsRAN
│
├── scripts/
│   ├── up.sh                 # Iniciar core + RAN
│   ├── up_core.sh            # Apenas core Open5GS
│   ├── up_ran.sh             # Apenas RAN (UERANSIM ou srsRAN)
│   ├── down.sh               # Parar tudo
│   │
│   ├── add-subscriber.sh     # Provisionar subscriber no MongoDB
│   ├── apply-nat-host.sh     # sysctl + iptables NAT no host (idempotente)
│   ├── troubleshoot.sh      # tcpdump, ip route, iptables counters
│   │
│   ├── healthcheck.sh
│   ├── test_ue_connection.sh
│   ├── test-system-status.sh
│   ├── capture-n3-n6-pcaps.sh
│   ├── init-udr.sh
│   └── init-pcf.sh
│
├── logs/                     # Logs por serviço
│   ├── amf/
│   ├── smf/
│   ├── upf-a/
│   ├── ueransim/             # ou srsran-gnb/, srsran-ue/
│   └── ...
│
├── docs/
│   ├── ESTRUTURA_ARVORE.md   # Este arquivo
│   ├── PLANO_MIGRACAO.md     # 4G EPC → 5G SA
│   ├── CHECKLIST_VALIDACAO.md
│   └── IP_ADDRESSING.md
│
├── docker/
│   └── srsue/               # Dockerfile srsUE (srsRAN 4G, ZMQ)
│       ├── Dockerfile
│       ├── entrypoint.sh
│       └── README.md
├── docker-compose.yml       # Core + RAN (UERANSIM padrão)
├── .env
├── .env.example
└── README.md
```

## Mapeamento de Configurações

| Componente | Arquivo | Propósito |
|------------|---------|-----------|
| AMF | amf.yaml | NGAP (10.20.0.11), TAC=7, PLMN 001/01, S-NSSAI SST=1 |
| SMF | smf.yaml | PFCP, DNN=internet, subnet 10.60.0.0/16 |
| UPF | upf-a.yaml | GTP-U N3 (10.30.0.21), PFCP N4, session 10.60.0.0/16 (pool completo) |
| gNB (UERANSIM) | ueransim/gnb.yaml | N2→AMF, N3→UPF, TAC, PLMN |
| gNB (srsRAN) | srsRAN/gnb.yaml | ZMQ, N2, N3, TAC, PLMN |
| UE (UERANSIM) | ueransim/ue.yaml | IMSI, K, OPc, DNN, gNB IP |
| UE (srsRAN) | srsRAN/ue.conf | ZMQ ports, USIM, APN, S-NSSAI |
