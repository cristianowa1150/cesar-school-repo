# Interface `upfgtp` e o Problema de IPv4

## O que é a interface `upfgtp`?

A interface `upfgtp` é uma **interface virtual** criada pelo módulo de kernel Linux `gtp5g`. Ela é usada pelo UPF (User Plane Function) do free5GC para:

1. **Receber pacotes GTP-U** do gNB (via interface N3)
2. **Encapsular/desencapsular pacotes GTP-U** para sessões PDU
3. **Encaminhar tráfego de dados** do UE para a Data Network (DN)

## Por que a interface precisa de um endereço IPv4?

### 1. **Comunicação GTP-U com o gNB**

O gNB precisa saber **qual endereço IP usar** para enviar pacotes GTP-U para o UPF. Quando o SMF estabelece uma sessão PDU, ele informa ao gNB:

- **F-TEID (Fully Qualified Tunnel Endpoint Identifier)** do UPF
- **Endereço IP do UPF** para a interface N3 (GTP-U)

Se a interface `upfgtp` não tiver um endereço IPv4, o gNB não consegue:
- Enviar pacotes GTP-U para o UPF
- Estabelecer túneis GTP-U para sessões PDU
- Encaminhar tráfego de dados do UE

### 2. **Roteamento de Pacotes**

O kernel Linux usa o endereço IP da interface para:
- **Roteamento**: Decidir por qual interface enviar pacotes
- **Encapsulamento GTP-U**: O módulo `gtp5g` precisa saber qual IP usar como source IP nos pacotes GTP-U

### 3. **Associação PFCP**

Embora a associação PFCP (N4) use a interface `eth0`, o SMF também precisa conhecer o endereço IP que o UPF usará para GTP-U (N3) para configurar corretamente as regras de encaminhamento.

## O Problema Identificado

Após instalar o módulo `gtp5g`, a interface `upfgtp` é criada automaticamente, mas:

```bash
$ ip addr show upfgtp
3: upfgtp: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1464 qdisc noqueue state UNKNOWN
    link/none 
    inet6 fe80::887:3b2a:7256:af55/64 scope link stable-privacy
```

**Problema**: A interface só tem um endereço **IPv6 link-local**, mas **não tem IPv4**.

## Implicações do Problema

### ❌ **Sessões PDU não podem ser estabelecidas**

- O SMF consegue estabelecer associação PFCP com o UPF (via `eth0`)
- Mas quando tenta criar uma sessão PDU, o gNB não consegue enviar pacotes GTP-U porque não há um endereço IPv4 válido na interface `upfgtp`

### ❌ **Tráfego de dados não funciona**

- Mesmo que uma sessão PDU seja criada, o tráfego de dados não funciona porque:
  - O gNB não sabe para onde enviar pacotes GTP-U
  - O UPF não consegue encapsular/desencapsular pacotes GTP-U corretamente

### ❌ **Testes E2E falham**

- Testes de ping do UE para internet falham
- Testes de conectividade E2E não funcionam

## Solução Implementada

### 1. **Atualização do `upf-iptables.sh`**

O script agora atribui automaticamente o IP do container (`eth0`) à interface `upfgtp`:

```bash
#!/bin/bash
#
# Configure iptables and network interfaces in UPF
#

# Get the IP address of the UPF container (eth0)
UPF_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

# Assign the UPF IP to the upfgtp interface (created by gtp5g module)
if ip link show upfgtp >/dev/null 2>&1; then
    echo "Configuring upfgtp interface with IP: $UPF_IP"
    ip addr add "$UPF_IP/32" dev upfgtp 2>/dev/null || true
    ip link set upfgtp up 2>/dev/null || true
fi

# Configure iptables for NAT and forwarding
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
iptables -I FORWARD 1 -j ACCEPT
```

### 2. **Atualização do `fix-upf.sh`**

O script de correção agora verifica e corrige automaticamente a interface `upfgtp`:

```bash
# Verificar se a interface upfgtp existe e tem IP
UPFGTP_IPV4=$(docker compose exec -T free5gc-upf ip addr show upfgtp | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)

if [ -z "$UPFGTP_IPV4" ]; then
    # Obter o IP do container e atribuir à interface upfgtp
    UPF_IP=$(docker compose exec -T free5gc-upf ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)
    docker compose exec -T free5gc-upf ip addr add "$UPF_IP/32" dev upfgtp
fi
```

## Verificação

Após aplicar a correção, verifique:

```bash
# 1. Verificar se a interface upfgtp tem IPv4
docker compose exec free5gc-upf ip addr show upfgtp

# Deve mostrar algo como:
# 3: upfgtp: <POINTOPOINT,MULTICAST,NOARP,UP,LOWER_UP> mtu 1464
#     inet 10.100.200.9/32 scope global upfgtp
#     inet6 fe80::887:3b2a:7256:af55/64 scope link

# 2. Verificar rotas
docker compose exec free5gc-upf ip route show

# Deve mostrar rotas para os pools de UE via upfgtp:
# 10.60.0.0/16 dev upfgtp proto static
# 10.61.0.0/16 dev upfgtp proto static

# 3. Verificar se o UPF está recebendo tráfego GTP-U
docker compose logs free5gc-upf | grep -i "gtpu\|pfcp"
```

## Referências

- [free5GC/go-upf - Compatibilidade gtp5g](https://github.com/free5gc/go-upf/tree/b798fe5ee6a984be492fa53958dd5f1305469f85)
- [Documentação do módulo gtp5g](https://github.com/free5gc/gtp5g)

