# Checklist de Validação e Troubleshooting - 5G SA

## 1. Verificar registros AMF/NRF

```bash
# NRF e NFs registradas
docker compose logs nrf --tail 30

# AMF aceitou gNB
docker compose logs amf --tail 50 | grep -E "gNB-N2|NG Setup|accepted"

# Contagem de gNBs conectados
docker compose logs amf 2>&1 | grep "Number of gNB" | tail -3
```

**Esperado:** `gNB-N2 accepted`, `Number of gNBs is now 1`

---

## 2. Verificar attach e PDU session

```bash
# UE registrado
docker compose logs ueransim --tail 100 | grep -E "MM-REGISTERED|Registration|PDU Session"

# IP atribuído ao UE
docker exec ueransim-containerized ip addr show | grep -E "inet |uesimtun"
```

**Esperado:** `MM-REGISTERED`, `PDU Session Establishment successful`, IP 10.60.x.x na interface uesimtun

---

## 3. Checar rota e iptables

```bash
# Rotas no UE
docker exec ueransim-containerized ip route show

# NAT no host (deve haver regra para 10.60.0.0/16)
sudo iptables -t nat -L POSTROUTING -v -n | grep 10.60

# IP forwarding
sysctl net.ipv4.ip_forward
```

**Esperado:** Rota default via gateway 10.60.0.1 (ou similar), regra MASQUERADE, ip_forward=1

---

## 4. tcpdump nos pontos críticos

```bash
# N2 (NGAP SCTP) - AMF 10.20.0.11:38412
./scripts/troubleshoot.sh capture-n2

# N3 (GTP-U) - UPF 10.30.0.21:2152
./scripts/troubleshoot.sh capture-n3

# Tráfego na TUN do UE
./scripts/troubleshoot.sh capture-ue
```

---

## 5. Testes de conectividade

```bash
# Obter IP do UE
UE_IP=$(docker exec ueransim-containerized ip -4 addr show uesimtun0 2>/dev/null | grep -oP 'inet \K[\d.]+' || echo "10.60.0.2")

# Ping do host para UE (downlink)
ping -c 2 $UE_IP

# Ping do UE para gateway (uplink)
docker exec ueransim-containerized ping -c 2 -I uesimtun0 10.60.0.1

# Ping do UE para internet (requer NAT no host)
docker exec ueransim-containerized ping -c 2 -I uesimtun0 8.8.8.8

# DNS (se NAT ok)
docker exec ueransim-containerized ping -c 2 -I uesimtun0 google.com

# iperf3 (servidor na rede N6 - 10.50.0.50)
docker compose --profile tools up -d iperf3-server
docker exec ueransim-containerized iperf3 -c 10.50.0.50 -B $UE_IP -t 5
```

---

## 6. Comandos úteis

| Objetivo | Comando |
|----------|---------|
| Status geral | `./scripts/troubleshoot.sh all` |
| Aplicar NAT | `./scripts/apply-nat-host.sh wlo1` |
| Adicionar subscriber | `./scripts/add-subscriber.sh` |
| Logs em tempo real | `docker compose logs -f ueransim amf smf` |
| Reiniciar UE | `docker compose restart ueransim` |

---

## 7. Problemas comuns

| Sintoma | Possível causa | Ação |
|---------|----------------|------|
| AMF context not found | gNB não conectou ao AMF | Verificar N2, TAC, PLMN |
| Registration rejected | Subscriber não existe | `./scripts/add-subscriber.sh` |
| Sem IP no UE | PDU session falhou | Verificar SMF/UPF, DNN=internet |
| Ping 8.8.8.8 falha | NAT não aplicado | `./scripts/apply-nat-host.sh wlo1` |
| DNS não resolve | NAT ou rota default | Verificar rota no UE |
