# Troubleshooting - free5GC

Este documento lista problemas comuns e suas soluções.

## 🔴 Problemas Críticos

### 1. UPF não está rodando

**Sintoma:**
```bash
docker compose ps free5gc-upf
# STATUS: Exited (0)
```

**Causas possíveis:**
- Script `upf-iptables.sh` falhou
- Problemas de permissão (NET_ADMIN)
- Configuração incorreta

**Solução:**
```bash
# Verificar logs
docker compose logs free5gc-upf

# Tentar corrigir automaticamente
./scripts/fix-upf.sh

# Ou reiniciar manualmente
docker compose restart free5gc-upf

# Se ainda não funcionar, recriar
docker compose up -d --force-recreate free5gc-upf
```

---

### 2. Associação PFCP não estabelecida (SMF <-> UPF)

**Sintoma:**
- Scripts reportam: "Associação PFCP não encontrada"
- SMF não consegue comunicar com UPF

**Causas possíveis:**
- UPF não está rodando
- Problemas de rede entre SMF e UPF
- Configuração incorreta do nodeID/addr no SMF

**Solução:**
```bash
# 1. Verificar se UPF está rodando
docker compose ps free5gc-upf

# 2. Verificar conectividade
docker compose exec free5gc-smf ping -c 1 upf.free5gc.org

# 3. Verificar logs do SMF
docker compose logs free5gc-smf | grep -i pfcp

# 4. Verificar configuração
grep -A 5 "upNodes" config/smfcfg.yaml
```

**Verificar configuração:**
- `config/smfcfg.yaml`: `nodeID: upf.free5gc.org` e `addr: upf.free5gc.org`
- `config/upfcfg.yaml`: `nodeID: upf.free5gc.org`

---

### 3. NG Setup não estabelecido (gNB <-> AMF)

**Sintoma:**
- Scripts reportam: "NG Setup não encontrado"
- gNB não consegue conectar ao AMF

**Causas possíveis:**
- AMF não está rodando
- IP do AMF incorreto no gNB
- Problemas de rede

**Solução:**
```bash
# 1. Verificar se AMF está rodando
docker compose ps free5gc-amf

# 2. Verificar IP do AMF
docker compose exec free5gc-amf ip addr show eth0

# 3. Verificar configuração do gNB
grep -A 3 "amf:" ../gNB/configs/gnb.yml

# 4. Verificar logs
docker compose logs free5gc-amf | grep -i "ng\|sctp"
docker compose logs srsran-gnb | grep -i "ng\|sctp"
```

**Verificar configuração:**
- `gNB/configs/gnb.yml`: `cu_cp.amf.addr`, `port: 38412`, `bind_addr` (IP do gNB)
- `config/amfcfg.yaml`: `ngapIpList` deve incluir o IP do AMF

#### 3.1 srsRAN gNB: "Network is unreachable" / restart loop (N2 over SCTP)

**Sintoma:**
- Log do gNB: `N2: Failed to connect to AMF on <AMF_IP>:38412. error="Network is unreachable" timeout=0ms` e `CU-CP failed to connect to AMF`
- Ping e roteamento do container gNB para o AMF funcionam; só SCTP falha
- Container `srsran-gnb` entra em restart loop assim que o AMF sobe

**Causa raiz:**  
O cliente SCTP do srsRAN não está fazendo bind no endereço local correto. Sem `bind_addr`, o kernel pode escolher uma origem errada (outra interface ou IPv6 sem rota), e o `connect()` SCTP devolve `ENETUNREACH` ("Network is unreachable"). Ver [srsRAN Discussion #322](https://github.com/srsran/srsRAN_Project/discussions/322).

**Solução:**  
Em `gNB/configs/gnb.yml`, na seção `cu_cp.amf`, definir `bind_addr` com o **IP do próprio gNB** na rede Docker (ex.: `10.100.200.50`):

```yaml
cu_cp:
  amf:
    addr: 10.100.200.16
    port: 38412
    bind_addr: 10.100.200.50   # IP do container gNB na privnet
```

Reiniciar o gNB após alterar a config.

**Sobre saída fatal:**  
O srsRAN Project trata falha na primeira conexão N2 como fatal (processo encerra com código 1). Não há opção de config para “só retentar” sem sair; o mitigador é corrigir a conectividade (em especial o `bind_addr`) e, se desejar, usar `restart: on-failure` no compose para reintentos automáticos.

---

### 4. Subscriber não encontrado

**Sintoma:**
- UE não consegue se registrar
- Erros de autenticação nos logs

**Solução:**
```bash
# Adicionar subscriber
./scripts/add-subscriber.sh

# Verificar se foi adicionado
docker compose exec db mongosh free5gc --quiet --eval "db.subscribers.find().pretty()"
```

---

## 🟡 Problemas Menores

### 5. Muitos erros no SMF

**Sintoma:**
- Scripts reportam centenas de erros no SMF

**Causa:**
- Geralmente são warnings ou erros não críticos
- Pode ser normal durante inicialização

**Solução:**
```bash
# Verificar erros críticos
docker compose logs free5gc-smf | grep -i "fatal\|panic" | tail -20

# Se não houver erros fatais, pode ser normal
# Verifique se PFCP está associado e se há sessões PDU
```

---

### 6. UE não encontra células

**Sintoma:**
- UE não consegue se conectar ao gNB

**Solução:**
```bash
# Verificar se gNB está rodando
docker compose ps srsran-gnb

# Verificar logs do gNB
docker compose logs srsran-gnb | grep -i "cell\|signal"

# UE (srsUE) corre no host; ver docs/CONECTAR_UE.md
```

---

## 🔧 Comandos Úteis

### Verificar status geral
```bash
./scripts/healthcheck.sh
```

### Testar sistema
```bash
./scripts/test.sh
```

### Testar E2E
```bash
./scripts/test-e2e.sh
```

### Ver logs de um serviço
```bash
docker compose logs -f free5gc-amf
docker compose logs -f free5gc-smf
docker compose logs -f free5gc-upf
docker compose logs -f srsran-gnb
```

### Reiniciar um serviço
```bash
docker compose restart free5gc-upf
docker compose restart free5gc-smf
```

### Recriar um serviço
```bash
docker compose up -d --force-recreate free5gc-upf
```

### Verificar conectividade de rede
```bash
# Entre AMF e gNB
docker compose exec free5gc-amf ping -c 3 10.100.200.50

# Entre SMF e UPF
docker compose exec free5gc-smf ping -c 3 upf.free5gc.org
```

---

## 📋 Checklist de Funcionamento

Para garantir que o sistema está funcional:

- [ ] MongoDB está rodando
- [ ] NRF está rodando e acessível
- [ ] AMF está registrado no NRF
- [ ] SMF está registrado no NRF
- [ ] UPF está rodando
- [ ] NG Setup estabelecido (gNB ↔ AMF)
- [ ] Associação PFCP estabelecida (SMF ↔ UPF)
- [ ] Subscriber existe no MongoDB
- [ ] UE pode se registrar (se houver UE configurado)
- [ ] Sessão PDU pode ser estabelecida

Execute `./scripts/test-e2e.sh` para verificar todos esses itens automaticamente.

---

## 🆘 Ainda com problemas?

1. **Verifique logs detalhados:**
   ```bash
   docker compose logs > all_logs.txt
   ```

2. **Verifique configurações:**
   - `config/amfcfg.yaml`
   - `config/smfcfg.yaml`
   - `config/upfcfg.yaml`
   - `config/gnbcfg.yaml`
   - `config/uecfg.yaml`

3. **Verifique rede Docker:**
   ```bash
   docker network inspect free5gc-containerized_privnet
   ```

4. **Reinicie tudo:**
   ```bash
   ./scripts/down.sh
   ./scripts/up.sh
   ```

5. **Consulte documentação:**
   - [free5GC Documentation](https://free5gc.org/)
   - [free5GC GitHub](https://github.com/free5gc/free5gc)

