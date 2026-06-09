#!/usr/bin/env bash
# Inicia o srscu dentro do container srsran-cu (modo CU_AUTO_START=0).
set -euo pipefail
CFG="${1:-cu.yml}"
exec docker exec -it srsran-cu srscu -c "/etc/srsran/${CFG}"
