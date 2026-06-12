#!/bin/bash
# Compatibilidade: o teste principal deste lab usa srsUE.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/test-srsue-e2e.sh" "$@"
