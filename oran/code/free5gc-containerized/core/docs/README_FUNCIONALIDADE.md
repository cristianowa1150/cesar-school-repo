# Guia de Funcionalidade - free5GC

Este documento explica o que é necessário para que o sistema free5GC esteja totalmente funcional e permita testes E2E (End-to-End).

## 🔴 Problemas Identificados e Soluções

### 1. UPF não está rodando

**Problema:**
- Container `upf` está com status `Exited (0)`
- Isso impede a associação PFCP (SMF ↔ UPF)
- Sem UPF, não há plano de dados funcional

**Causa:**
- O script `upf-iptables.sh` pode estar falhando
- Problemas de permissão ou configuração

**Solução:**
```bash
# Opção 1: Usar script de correção
./scripts/fix-upf.sh

# Opção 2: Reiniciar manualmente
docker compose restart free5gc-upf

# Opção 3: Verificar logs e corrigir
docker compose logs free5gc-upf
docker compose up -d --force-recreate free5gc-upf
```

**Verificação:**
```bash
docker compose ps free5gc-upf
# Deve mostrar: STATUS: Up
```

---

### 2. Associação PFCP não estabelecida

**Problema:**
- SMF não consegue associar com UPF via PFCP (N4)
- Sem PFCP, não há sessões PDU

**Causa:**
- UPF não está rodando (problema #1)
- Configuração incorreta de nodeID/addr
- Problemas de rede entre SMF e UPF

**Solução:**
1. **Garantir que UPF está rodando** (ver problema #1)
2. **Verificar configuração:**
   ```bash
   # SMF deve ter:
   grep -A 3 "UPF:" config/smfcfg.yaml
   # Deve mostrar: nodeID: upf.free5gc.org
   
   # UPF deve ter:
   grep -A 2 "pfcp:" config/upfcfg.yaml
   # Deve mostrar: nodeID: upf.free5gc.org
   ```
3. **Verificar conectividade:**
   ```bash
   docker compose exec free5gc-smf ping -c 3 upf.free5gc.org
   ```

**Verificação:**
```bash
docker compose logs free5gc-smf | grep -i "pfcp.*associated"
# Deve mostrar mensagens de associação bem-sucedida
```

---

### 3. Subscriber não configurado

**Problema:**
- UE não consegue se registrar
- Erros de autenticação

**Causa:**
- Subscriber não existe no MongoDB
- Credenciais não batem entre UE e Core

**Solução:**
```bash
# Adicionar subscriber automaticamente
./scripts/add-subscriber.sh

# Ou verificar manualmente
docker compose exec db mongosh free5gc --quiet --eval "db.subscribers.find().pretty()"
```

**Verificação:**
- Subscriber com SUPI `imsi-208930000000001` deve existir
- Credenciais (K, OP, OPC) devem bater com `config/uecfg.yaml`

---

### 4. NG Setup não estabelecido

**Problema:**
- gNB não consegue conectar ao AMF
- Sem NG Setup, não há comunicação N2

**Causa:**
- AMF não está rodando
- IP/porta incorretos no gNB
- Problemas de rede

**Solução:**
1. **Verificar AMF:**
   ```bash
   docker compose ps free5gc-amf
   docker compose logs free5gc-amf | grep -i "ngap\|sctp"
   ```

2. **Verificar configuração do gNB:**
   ```bash
   grep -A 3 "amf:" ../gNB/configs/gnb.yml
   # Deve mostrar: addr, port: 38412, bind_addr
   ```

3. **Verificar conectividade:**
   ```bash
   docker compose exec srsran-gnb ping -c 3 amf.free5gc.org
   ```

**Verificação:**
```bash
docker compose logs free5gc-amf | grep -i "NGSetupRequest\|SCTP Accept"
# Deve mostrar conexões do gNB
```

---

## ✅ Checklist de Funcionalidade

Para garantir que o sistema está pronto para testes E2E:

### Infraestrutura Base
- [ ] MongoDB está rodando e acessível
- [ ] NRF está rodando e registrado no MongoDB
- [ ] Todos os NFs estão registrados no NRF

### Control Plane
- [ ] AMF está rodando e registrado no NRF
- [ ] SMF está rodando e registrado no NRF
- [ ] AUSF, UDM, UDR, PCF, NSSF estão rodando

### User Plane
- [ ] **UPF está rodando** (CRÍTICO)
- [ ] Associação PFCP estabelecida (SMF ↔ UPF)
- [ ] UPF tem permissões NET_ADMIN

### RAN
- [ ] gNB (srsRAN) está rodando
- [ ] NG Setup estabelecido (gNB ↔ AMF)
- [ ] gNB pode alcançar AMF via rede

### Dados
- [ ] **Subscriber existe no MongoDB** (CRÍTICO)
- [ ] Credenciais do UE batem com o subscriber
- [ ] UE pode se registrar no AMF

### Sessão PDU
- [ ] UE recebe IP da sessão PDU
- [ ] Túnel GTP-U estabelecido (gNB ↔ UPF)
- [ ] UE pode acessar internet (via N6)

---

## 🚀 Sequência Recomendada para Testes E2E

### 1. Inicializar Sistema

```bash
./scripts/up.sh
```

Este script:
- Inicia serviços na ordem correta
- Verifica se UPF iniciou corretamente
- Adiciona subscriber automaticamente se necessário

### 2. Verificar Saúde

```bash
./scripts/healthcheck.sh
```

Verifique:
- Todos os serviços estão rodando
- NG Setup estabelecido
- PFCP associado
- Subscriber existe

### 3. Corrigir Problemas (se necessário)

```bash
# Se UPF não está rodando
./scripts/fix-upf.sh

# Se subscriber não existe
./scripts/add-subscriber.sh
```

### 4. Testar E2E

```bash
./scripts/test-e2e.sh
```

Este script verifica:
- UPF está rodando
- Subscriber existe
- NG Setup estabelecido
- PFCP associado
- Registro de UE
- Sessão PDU

### 5. Iniciar UE (se houver container UE separado)

Se você tiver um container UE separado (não apenas o gNB):

```bash
# Verificar se há container UE no docker-compose.yaml
# UE (srsUE) corre no host; ver docs/CONECTAR_UE.md
docker compose logs srsran-gnb | grep -i "ng\|cell"
```

---

## 🔧 Scripts Disponíveis

### Scripts Principais

1. **`scripts/up.sh`** - Inicializa todo o sistema
   - Inicia serviços na ordem correta
   - Verifica UPF
   - Adiciona subscriber automaticamente

2. **`scripts/down.sh`** - Encerra o sistema
   - Para todos os containers
   - Opção para remover volumes

3. **`scripts/healthcheck.sh`** - Verifica saúde
   - Status dos containers
   - Conectividade de rede
   - NG Setup, PFCP, registro de NFs

4. **`scripts/test.sh`** - Testes básicos
   - Acessibilidade de serviços
   - Registro de NFs
   - Conectividade

### Scripts Específicos

5. **`scripts/test-e2e.sh`** - Testes End-to-End
   - Verifica todos os componentes críticos
   - Valida fluxo completo
   - Sugere correções

6. **`scripts/add-subscriber.sh`** - Adiciona subscriber
   - Cria subscriber no MongoDB
   - Usa credenciais do uecfg.yaml
   - Verifica se já existe

7. **`scripts/fix-upf.sh`** - Corrige UPF
   - Reinicia UPF se não estiver rodando
   - Recria container se necessário
   - Mostra logs para diagnóstico

---

## 📊 Interpretação dos Testes

### Testes Passando ✅
- Sistema está funcional
- Pronto para testes E2E
- UE deve conseguir se registrar

### Alguns Testes Falhando ⚠️
- Sistema pode estar funcionando parcialmente
- Verifique os itens do checklist
- Execute scripts de correção

### Muitos Testes Falhando ❌
- Há problemas significativos
- Verifique logs detalhados
- Siga o troubleshooting guide

---

## 🎯 Próximos Passos para E2E Completo

1. **Garantir UPF rodando:**
   ```bash
   ./scripts/fix-upf.sh
   ```

2. **Garantir subscriber:**
   ```bash
   ./scripts/add-subscriber.sh
   ```

3. **Verificar tudo:**
   ```bash
   ./scripts/test-e2e.sh
   ```

4. **Iniciar UE (se necessário):**
   - Configure e execute srsUE no host (ver docs/CONECTAR_UE.md)
   - Verifique logs de registro
   - Teste conectividade

5. **Validar E2E:**
   - UE registra no AMF
   - Sessão PDU é estabelecida
   - UE recebe IP
   - UE pode acessar internet

---

## 📚 Documentação Adicional

- **Troubleshooting:** `README_TROUBLESHOOTING.md`
- **Docker Compose:** `docs/DOCKER_COMPOSE_EXPLAINED.md`
- **Scripts:** `README_SCRIPTS.md`

---

## ✅ Resumo

Para o sistema estar funcional e permitir testes E2E:

1. ✅ **UPF deve estar rodando** - Use `./scripts/fix-upf.sh`
2. ✅ **Subscriber deve existir** - Use `./scripts/add-subscriber.sh`
3. ✅ **NG Setup deve estar estabelecido** - Verifique logs do AMF
4. ✅ **PFCP deve estar associado** - Verifique logs do SMF após UPF estar rodando
5. ✅ **UE deve estar configurado** - Verifique `config/uecfg.yaml`

Execute `./scripts/test-e2e.sh` para validar tudo automaticamente!

