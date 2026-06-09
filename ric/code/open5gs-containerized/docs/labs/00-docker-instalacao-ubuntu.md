# Roteiro — Instalação do Docker Engine e Docker Compose v2 (Ubuntu)

**Objetivo:** instalar **Docker Engine** e o plugin **Docker Compose v2** (`docker compose`) em **Ubuntu 22.04 LTS** ou **24.04 LTS**, no formato exigido pelos laboratórios [01 — Core](01-core-open5gs.md) e [02 — UERANSIM](02-ueransim-n2-n3-e2e.md).

**Onde usar:** máquina física, VM local (VirtualBox/VMware), **VM no GCP** ([Roteiro 00 — GCP](00-pre-lab-gcp-vm-e-acesso.md)) ou outro provedor — os comandos são os mesmos no Ubuntu.

**Referência canônica (atualizações):** [Install Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/).

---

## 1. Remover pacotes antigos (opcional, recomendado se já houve Docker distro)

Evita conflito com versões empacotadas pela distribuição:

```bash
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
  sudo apt-get remove -y "$pkg" 2>/dev/null || true
done
```

---

## 2. Dependências e chave do repositório oficial Docker

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
```

---

## 3. Adicionar o repositório *apt* da Docker

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
$(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Se `apt-get update` falhar com erro de *codename*, confira `VERSION_CODENAME` com `grep VERSION_CODENAME /etc/os-release` e compare com as versões suportadas na documentação da Docker.

---

## 4. Instalar Docker Engine e Compose v2

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

- **`docker compose`** vem do pacote **`docker-compose-plugin`** (subcomando `docker compose`, *v2*).

---

## 5. Serviço e inicialização

```bash
sudo systemctl enable --now docker
sudo systemctl status docker --no-pager
```

Saída esperada: *active (running)*.

---

## 6. Usuário sem `sudo` (grupo `docker`)

```bash
sudo usermod -aG docker "$USER"
```

**É necessário encerrar a sessão SSH (ou fazer *logoff* no terminal gráfico) e conectar de novo**, ou executar na sessão atual:

```bash
newgrp docker
```

Sem isso, comandos `docker` falham com *permission denied*.

---

## 7. Verificação (obrigatória para o relatório / vídeo)

```bash
docker --version
docker compose version
docker info
```

**Teste rápido (opcional):**

```bash
docker run --rm hello-world
```

**Evidência alinhada ao Roteiro 01:** anexe ou mostre as primeiras linhas de `docker --version`, `docker compose version` e `uname -a` (o `uname` pode ser executado no mesmo bloco).

---

## 8. Problemas frequentes

| Sintoma | O que fazer |
| ------- | ----------- |
| `permission denied` ao rodar `docker` | Grupo `docker`: `newgrp docker` ou nova sessão SSH após `usermod`. |
| `docker compose` não encontrado | Confirme o pacote `docker-compose-plugin` (ex.: `dpkg -l` e busque por esse nome). |
| Proxy corporativo | Configure proxy para `apt` e para o *daemon* Docker conforme a política da rede. |
| ARM64 (`aarch64`) | O repositório acima usa `dpkg --print-architecture`; use imagens dos *compose* compatíveis com ARM ou espere emulação, conforme o projeto. |

---

## Checklist

- [ ] `docker-ce`, `docker-compose-plugin` instalados.
- [ ] `sudo systemctl status docker` → *running*.
- [ ] Usuário no grupo `docker` e sessão renovada.
- [ ] `docker compose version` responde com *v2*.
- [ ] (Opcional) `docker run --rm hello-world` conclui com sucesso.

**Próximo passo:** [Roteiro 00 — GCP](00-pre-lab-gcp-vm-e-acesso.md) (se ainda faltar VM/clone) ou [01 — Core](01-core-open5gs.md).
