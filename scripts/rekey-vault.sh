#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if [[ ! -f group_vars/all/vault.yml ]]; then
  echo "Missing group_vars/all/vault.yml — run scripts/bootstrap.sh first"
  exit 1
fi

echo "This replaces the lab vault password with a new one you type."
echo "Current password file is .vault_pass (lab default: homelab)."
read -r -s -p "New vault password: " NEW_PASS
echo
read -r -s -p "Repeat new vault password: " NEW_PASS2
echo

if [[ "${NEW_PASS}" != "${NEW_PASS2}" ]]; then
  echo "Passwords do not match."
  exit 1
fi

ansible-vault rekey group_vars/all/vault.yml --new-vault-password-file <(printf '%s' "${NEW_PASS}")
printf '%s\n' "${NEW_PASS}" > .vault_pass
chmod 600 .vault_pass
echo "Vault re-keyed. Updated .vault_pass (do not commit that file)."
