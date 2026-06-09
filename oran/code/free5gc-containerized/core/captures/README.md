# Capturas de rede (N2 / N3)

Este diretório é usado pelos scripts `scripts/capture-n2.sh` e `scripts/capture-n3.sh`.

- **N2:** SCTP porta 38412 (NGAP entre gNB e AMF). Nomes: `n2_YYYYMMDD_HHMMSS.pcap`.
- **N3:** UDP porta 2152 (GTP-U entre gNB e UPF). Nomes: `n3_YYYYMMDD_HHMMSS.pcap`.

As capturas são feitas na interface da bridge Docker (`br-free5gc`). Analise com Wireshark ou `tcpdump -r <arquivo> -nn`.

Consulte `docs/VALIDATION_E2E.md` para filtros e interpretação.
