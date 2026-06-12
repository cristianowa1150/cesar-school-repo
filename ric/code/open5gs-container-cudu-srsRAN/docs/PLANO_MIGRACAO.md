# Plano de Migração: 4G EPC + srsENB/srsUE → 5G SA + Open5GS + srsRAN ZMQ

## Mapeamento de componentes

| 4G EPC / LTE | 5G SA |
|--------------|-------|
| MME | AMF |
| HSS | UDM + UDR + AUSF |
| S-GW / P-GW | SMF + UPF |
| srsENB (eNB) | srsgNB (srsRAN Project) ou UERANSIM gNB |
| srsUE (LTE) | srsUE (5G NR) ou UERANSIM UE |
| S1-C/S1-U | N2 (NGAP) / N3 (GTP-U) |

---

## Mapeamento de IPs e redes Docker

| Rede | 4G (exemplo) | 5G SA (este projeto) |
|------|--------------|------------------------|
| Core SBI | - | 10.10.0.0/16 (net-sbi) |
| N2 (gNB↔AMF) | S1-C | 10.20.0.0/16 (net-n2) |
| N3 (gNB↔UPF) | S1-U | 10.30.0.0/16 (net-n3) |
| N4 (SMF↔UPF) | - | 10.40.0.0/16 (net-n4) |
| N6 (UPF↔DN) | SGi | 10.50.0.0/16 (net-n6) |
| Subnet UE | 172.16.0.0/24 ou similar | 10.60.0.0/16 |

**Interfaces:**
- AMF: 10.20.0.11 (N2)
- gNB: 10.20.0.100 (N2), 10.30.0.100 (N3)
- UPF: 10.30.0.21 (N3), 10.40.0.21 (N4), 10.50.0.21 (N6)

---

## PLMN, TAC, NCI, NR-ARFCN, SSB

| Parâmetro | Valor | Arquivo |
|-----------|-------|---------|
| MCC | 001 | amf.yaml, gnb.yaml, ue |
| MNC | 01 | idem |
| TAC | 7 | amf.yaml (tai), gnb.yaml |
| gNB ID | 0x19B ou 0x1 | gnb.yaml (nci) |
| NR-ARFCN DL | 368500 (n3, 1842.5 MHz) | gnb.yaml (dl_arfcn) |
| Band | 3 (FDD 1800) | gnb.yaml |
| S-NSSAI SST | 1 | amf, smf, gnb, ue |
| S-NSSAI SD | 0 ou 1 | (opcional, AMF pode não suportar) |

---

## Parâmetros do subscriber

| Campo | Valor | Descrição |
|-------|-------|-----------|
| IMSI | 001010000000001 | MCC+MNC+MSIN |
| K | 465B5CE8B199B49FAA5F0A2EE238A6B0 | Chave de autenticação |
| OP/OPc | E8ED289DEBA952E4283B54E88E6183B8 | OPc (Milenage) |
| AMF | 8000 | Authentication Management Field |
| DNN/APN | internet | Data Network Name |
| S-NSSAI | SST=1 | Slice |

---

## Rotas e NAT para tráfego UE → internet

1. **IP forwarding no host:**
   ```bash
   sudo sysctl -w net.ipv4.ip_forward=1
   ```

2. **NAT (substitua wlo1 pela sua interface de internet):**
   ```bash
   sudo iptables -t nat -A POSTROUTING -s 10.60.0.0/16 -o wlo1 -j MASQUERADE
   ```

3. **Script idempotente:**
   ```bash
   ./scripts/apply-nat-host.sh wlo1
   ```

---

## srsRAN vs UERANSIM

| Critério | UERANSIM | srsRAN (gNB + UE) |
|----------|----------|---------------------|
| Imagem Docker | gradiant/ueransim (pronta) | Requer build (srsRAN Project + srsRAN 4G) |
| Config | YAML | gNB: YAML, UE: .conf (libconfig) |
| ZMQ | Não (simula rádio em SW) | Sim (gNB↔UE via ZMQ) |
| Tráfego E2E hoje | ✅ Funcional | Requer build e integração |

**Recomendação:** Use UERANSIM para validar o core e ter tráfego IP fim-a-fim imediatamente. Para srsRAN ZMQ, siga [open5gs_5gc_srsran_sample_config](https://github.com/s5uishida/open5gs_5gc_srsran_sample_config) e construa as imagens a partir do source.
