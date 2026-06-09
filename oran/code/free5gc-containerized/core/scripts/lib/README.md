# `scripts/lib/` — código compartilhado

Esta pasta contém **apenas** arquivos que outros scripts carregam com `source` (por exemplo `. "$SCRIPT_DIR/lib/ran-docker.sh"`).

Não são comandos que o aluno corre diretamente: são “bibliotecas” bash para evitar repetir a mesma lógica em `validate-n2-ngap.sh`, `healthcheck.sh`, `test.sh`, etc.

O nome **`lib/`** é uma convenção comum em projetos para “arquivos incluídos / dependentes”.
