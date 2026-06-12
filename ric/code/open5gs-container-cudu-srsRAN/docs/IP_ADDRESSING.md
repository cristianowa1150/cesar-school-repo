# Endereçamento IP - 5G SA Open5GS + UERANSIM

## Redes Docker

| Rede | CIDR | Gateway | Propósito |
|------|------|---------|-----------|
| net-sbi | 10.10.0.0/16 | 10.10.0.1 | SBI entre NFs (NRF, AMF, SMF, etc.) |
| net-n2 | 10.20.0.0/16 | 10.20.0.1 | N2 (NGAP) gNB ↔ AMF |
| net-n3 | 10.30.0.0/16 | 10.30.0.1 | N3 (GTP-U) gNB ↔ UPF |
| net-n4 | 10.40.0.0/16 | 10.40.0.1 | N4 (PFCP) SMF ↔ UPF |
| net-n6 | 10.50.0.0/16 | 10.50.0.1 | N6 (Data) UPF ↔ DN |

## IPs por serviço

| Serviço | net-sbi | net-n2 | net-n3 | net-n4 | net-n6 |
|---------|---------|--------|--------|--------|--------|
| NRF | 10.10.0.10 | - | - | - | - |
| SCP | 10.10.0.200 | - | - | - | - |
| AMF | 10.10.0.11 | 10.20.0.11 | - | - | - |
| SMF | 10.10.0.12 | - | - | 10.40.0.12 | - |
| UPF-A | - | - | 10.30.0.21 | 10.40.0.21 | 10.50.0.21 |
| UPF-B | - | - | 10.30.0.22 | 10.40.0.22 | 10.50.0.22 |
| UERANSIM (gNB+UE) | - | 10.20.0.100 | 10.30.0.100 | - | - |
| WebUI | 10.10.0.100 | - | - | - | - |
| DN | - | - | - | - | 10.50.0.100 |

## Subnet UE (session)

- **Pool:** 10.60.0.0/16 (alocado pelo SMF; round-robin entre UPF-A e UPF-B)
- **Gateway (UPF):** 10.60.0.1 (ambas as UPFs cobrem o pool completo 10.60.0.0/16, ogstun + NAT)
- **UE típico:** 10.60.0.2, 10.60.0.3, ...

> Observação: o SMF aloca IPs de um pool único 10.60.0.0/16 e faz round-robin entre as UPFs.
> Por isso **ambas** as UPFs precisam cobrir o pool inteiro (ogstun 10.60.0.1/16 + MASQUERADE 10.60.0.0/16).
> Um split por metade (/17) faria o UE perder conectividade quando o IP alocado não correspondesse à UPF
> selecionada — e também quebraria o failover, pois a UPF sobrevivente deve atender qualquer IP do pool.

## Fluxo de tráfego

```
UE (10.60.0.2) → TUN uesimtun0 → gNB (10.30.0.100) → GTP-U N3 → UPF (10.30.0.21)
                                                                    ↓
                                                            N6 → DN / Internet
                                                                    ↓
                                                    NAT (host) → wlo1 → Internet
```
