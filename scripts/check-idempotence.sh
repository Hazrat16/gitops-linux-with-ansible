#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

PLAYBOOK="${1:-site.yml}"
LOG="$(mktemp)"

echo "==> First run (may report changes)"
ansible-playbook "${PLAYBOOK}"

echo "==> Second run (expect changed=0 unless config actually changed)"
ansible-playbook "${PLAYBOOK}" | tee "${LOG}"

if grep -E 'changed=[1-9]' "${LOG}"; then
  echo
  echo "Idempotence check FAILED: second run still reported changes."
  exit 1
fi

echo
echo "Idempotence check PASSED: second run reported no unexpected changes."
rm -f "${LOG}"
