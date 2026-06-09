# Documentação Consolidada - RAN (UERANSIM)

Documento único com as principais informações sobre a RAN e o UERANSIM.

---

## 1. Visão Geral

O UERANSIM simula gNB e UE para testes com o Core Open5GS. O compose RAN usa as redes externas `net-n2` e `net-n3` criadas pelo Core — **o Core deve ser iniciado primeiro**.

---

## 2. Configuração do gNB

### gnb.yaml

- **PLMN**: MCC=001, MNC=01
- **TAC**: 7 (deve corresponder ao AMF)
- **IPs**: linkIp/ngapIp em N2 (10.20.0.101), gtpIp em N3 (10.30.0.11)
- **AMF**: 10.20.0.11:38412
- **Slices**: SST=1 (sem SD — AMF não suporta SD)

### Rede

- **N2**: Comunicação com AMF (NGAP)
- **N3**: Tráfego de dados com UPF (GTP-U)

---

## 3. Configuração do UE

### ue.yaml

- **SUPI**: imsi-001010000000002
- **Keys**: K, OP, OPC conforme subscriber no MongoDB
- **gnbSearchList**: 10.20.0.101 (IP do gNB)
- **Sessão**: IPv4, APN=internet, SST=1

### Campos Obrigatórios

```yaml
integrityMaxRate:
  uplink: full
  downlink: full

uacAic:
  mps: false
  mcs: false

uacAcc:
  normalClass: 0
  class11: false
  class12: false
  class13: false
  class14: false
  class15: false
```

**Nota**: `integrityMaxRate` deve ser objeto com `uplink` e `downlink`; formato escalar causa erro de parsing.

---

## 4. Versão do UERANSIM

- **Recomendado**: v3.2.6
- **Evitar**: v3.2.7 — bug "AMF context not found" após NG Setup

Se usar v3.2.7, o NG Setup pode ser bem-sucedido, mas o UE não consegue registrar (timer T3510 expira).

---

## 5. Rota Padrão do UE (Bypass da Sessão PDU)

### Problema

O UE pode ter rota padrão via rede Docker (10.20.0.1 em eth0) em vez da sessão PDU (10.60.0.1 em eth1), fazendo o tráfego bypassar a UPF.

### Solução

Script `ue-entrypoint-fix-route.sh` no entrypoint do UE:

1. Aguarda IP na interface eth1 (10.60.x.x)
2. Verifica se gateway 10.60.0.1 está acessível
3. Remove rota padrão antiga
4. Adiciona `default via 10.60.0.1 dev eth1`

### Verificação

```bash
docker exec ueransim ip route show default
# Esperado: default via 10.60.0.1 dev eth1
```

---

## 6. Subscriber no MongoDB

O subscriber deve existir antes do UE registrar. Formato correto:

```json
{
  "imsi": "001010000000002",
  "subscriber_profile": {
    "name": "default",
    "type": 1
  },
  "security": {
    "k": "465B5CE8B199B49FAA5F0A2EE238A6B0",
    "opc": "E8ED289DEBA952E4283B54E88E6183B8",
    "amf": "8000",
    "op_type": 1
  },
  "slice": [{
    "sst": 1,
    "default_indicator": true,
    "session": [{
      "name": "internet",
      "type": 3,
      "qos": { "index": 9 },
      "ambr": { "downlink": 1024000, "uplink": 1024000 }
    }]
  }]
}
```

Use `add-subscriber.sh` no Core para adicionar.

---

## 7. Scripts

### test_ue_connection.sh

- Verifica IP do UE
- Ping para 8.8.8.8, 8.8.4.4, 1.1.1.1
- DNS, HTTP
- Rota padrão e conectividade

### up_ran.sh / down_ran.sh

- Sobe/desce o compose RAN (gNB + UE)

---

## 8. Troubleshooting

### UE não encontra células

- UE e gNB na mesma rede (net-n2)
- Ping gNB: `docker exec ueransim ping 10.20.0.101`
- TAC do gNB = 7 (igual ao AMF)

### NG Setup OK, mas registro falha

- Sintoma: "AMF context not found"
- Solução: usar UERANSIM v3.2.6
- Verificar: `docker compose logs ueransim-gnb | grep "AMF context"`

### UE com IP mas tráfego não passa pela UPF

- Verificar rota: `default via 10.60.0.1 dev eth1`
- Executar `ue-entrypoint-fix-route.sh` ou reiniciar UE com entrypoint correto

### Estado do UE

```bash
docker compose logs ueransim-ue | grep "UE switches to state"
# Esperado: MM-REGISTERED
# Problema: MM-DEREGISTERED/ATTEMPTING-REGISTRATION
```

---

## 9. Fluxo de Registro

1. UE encontra gNB (gnbSearchList)
2. RRC connection established
3. UE → gNB → AMF (N2): Registration Request
4. AMF → AUSF → UDM: autenticação
5. AMF → SMF: criação de sessão PDU
6. SMF → UPF: PFCP
7. AMF → gNB: Registration Accept
8. UE recebe IP (10.60.0.10) na interface PDU

---

## 10. Referências

- [UERANSIM](https://github.com/aligungr/UERANSIM)
- [UERANSIM Release Notes](https://github.com/aligungr/UERANSIM/wiki/Release-Notes)

---

*Última atualização: 2026-03*
