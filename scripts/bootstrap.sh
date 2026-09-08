#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

if ! command -v ansible-galaxy >/dev/null 2>&1; then
  echo "Install Ansible first (see BUILD-GUIDE.md section 4)."
  exit 1
fi

echo "==> Installing Ansible collections"
ansible-galaxy collection install -r requirements.yml

if [[ ! -f .vault_pass ]]; then
  echo "==> Writing lab vault password file (.vault_pass)"
  echo 'homelab' > .vault_pass
  chmod 600 .vault_pass
fi

if [[ ! -f inventory.ini ]]; then
  echo "==> Creating inventory.ini from the example — edit the private IPs"
  cp inventory.ini.example inventory.ini
fi

VAULT_FILE="group_vars/all/vault.yml"
if [[ ! -f "${VAULT_FILE}" ]]; then
  echo "==> Creating ${VAULT_FILE} from the example"
  cp group_vars/all/vault.yml.example "${VAULT_FILE}"
fi

if grep -q '^vault_db_password:' "${VAULT_FILE}"; then
  echo "==> Encrypting ${VAULT_FILE} with Ansible Vault"
  ansible-vault encrypt "${VAULT_FILE}"
fi

echo
echo "Bootstrap complete. Next: ansible-inventory --graph && ansible all -m ping"
