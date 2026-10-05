#!/usr/bin/env bash
# Compatibility wrapper. Bootstrap generation is now capability-neutral.
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "$root/scripts/generate-bootstrap-pointers.sh" legal-operating-defaults
