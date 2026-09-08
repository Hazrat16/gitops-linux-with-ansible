# Ansible Classroom Kit

AWS only. You will create **3 Ubuntu EC2 machines**: 1 control node and 2 managed nodes. All Ansible commands run **on the control node**, not on your laptop.

| Name | Role | What you do with it |
|------|------|---------------------|
| `control` | Ansible master | Install Ansible, copy the `.pem`, run playbooks |
| `web1` | Managed node | Nginx classroom demo, then Nginx + FastAPI |
| `db1` | Managed node | PostgreSQL + backups |

Same SSH key on all three. Port **22** open from your instructor/laptop IP. Port **80** open on `web1` for the web demo.

---

## Prerequisites

On your **laptop**:

- An AWS account and an IAM user that can create VPC/EC2
- AWS CLI and Terraform (install commands are below)
- This repository

On **AWS**:

- 3 × Ubuntu 22.04 EC2 (Terraform creates them)
- One key pair shared by all instances
- Security groups: SSH 22 from your IP; HTTP 80 (and 443) on web

Do **not** use Amazon Linux. The playbooks are Ubuntu-only.

---

## 1. Laptop — AWS CLI, Terraform, and an SSH key

```bash
sudo apt update
sudo apt install -y unzip curl git

curl -fsSL https://releases.hashicorp.com/terraform/1.9.8/terraform_1.9.8_linux_amd64.zip -o /tmp/terraform.zip
sudo unzip -o /tmp/terraform.zip -d /usr/local/bin
terraform version

curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
unzip -o /tmp/awscliv2.zip -d /tmp
sudo /tmp/aws/install
aws --version
```

```bash
aws configure
aws sts get-caller-identity
```

Create the key that every instance will use:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/homelab-ec2 -C homelab-ec2 -N ""
chmod 400 ~/.ssh/homelab-ec2
```

Lock SSH to your current public IP:

```bash
curl -s https://checkip.amazonaws.com
```

---

## 2. Laptop — create the 3 EC2 machines

```bash
cd /media/hazrat/Hazrat4/Code/devops/gitops-linux-platform-with-ansible
# or: cd ~/gitops-linux-platform-with-ansible

cd terraform/aws
cp example.tfvars terraform.tfvars
nano terraform.tfvars
```

```hcl
aws_region           = "us-east-1"
project_prefix       = "homelab"
instance_type        = "t3.small"
ssh_public_key_path  = "~/.ssh/homelab-ec2.pub"
ssh_private_key_path = "~/.ssh/homelab-ec2"
allowed_ssh_cidr     = "YOUR.PUBLIC.IP/32"
allowed_http_cidr    = "0.0.0.0/0"
```

Replace `YOUR.PUBLIC.IP` with the address from `checkip.amazonaws.com`.

```bash
terraform init
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output
```

Write down:

- `control_public_ip` — you SSH here
- `web_public_ip` — browser demo (`http://THIS_IP/`)
- `private_ips` — go into `inventory.ini` on the control node

Terraform also writes `inventory.ini` at the repo root on your laptop. You will copy that file to the control node.

---

## 3. Laptop — SSH to the control node

```bash
CONTROL_IP=$(terraform -chdir=/media/hazrat/Hazrat4/Code/devops/gitops-linux-platform-with-ansible/terraform/aws output -raw control_public_ip)
ssh -i ~/.ssh/homelab-ec2 ubuntu@${CONTROL_IP}
```

All commands from here until section 10 are on **the control node** unless it says “From local terminal”.

---

## 4. Control node — install Ansible

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt update
sudo apt install ansible -y
ansible --version
```

You should see something like:

```text
ansible [core 2.x.x]
  config file = /etc/ansible/ansible.cfg
  ...
  executable location = /usr/bin/ansible
```

---

## 5. Copy the private key onto the control node

The public key is already on all three instances. The **private** key is still on your laptop. The control node needs it to SSH to `web1` and `db1`.

On the **control node**:

```bash
mkdir -p /home/ubuntu/keys
```

From your **local terminal** (new tab, stay on the laptop):

```bash
CONTROL_IP=REPLACE_WITH_CONTROL_PUBLIC_IP

scp -i ~/.ssh/homelab-ec2 \
  ~/.ssh/homelab-ec2 \
  ubuntu@${CONTROL_IP}:/home/ubuntu/keys/homelab-ec2.pem
```

`ubuntu@${CONTROL_IP}` is your EC2 connection. You can also use the public DNS, for example:

```text
ubuntu@ec2-44-251-22-118.us-west-2.compute.amazonaws.com
```

Back on the **control node**:

```bash
chmod 400 /home/ubuntu/keys/homelab-ec2.pem
ls -l /home/ubuntu/keys
```

---

## 6. Control node — get this project

**Option A — copy the repo from your laptop** (includes the Terraform-generated `inventory.ini`):

From the **laptop**:

```bash
CONTROL_IP=REPLACE_WITH_CONTROL_PUBLIC_IP

scp -i ~/.ssh/homelab-ec2 -r \
  /media/hazrat/Hazrat4/Code/devops/gitops-linux-platform-with-ansible \
  ubuntu@${CONTROL_IP}:/home/ubuntu/gitops-linux-platform-with-ansible
```

**Option B — clone on the control node**, then paste private IPs yourself:

```bash
sudo apt install -y git
git clone https://github.com/YOUR_USER/gitops-linux-platform-with-ansible.git
cd gitops-linux-platform-with-ansible
cp inventory.ini.example inventory.ini
nano inventory.ini
```

Put the **private** IPs from `terraform output private_ips` into `ansible_host`, `homelab_web_ip`, `homelab_db_ip`, and `nginx_health_host`.

---

## 7. Control node — collections, vault, inventory

```bash
cd /home/ubuntu/gitops-linux-platform-with-ansible

ansible-galaxy collection install -r requirements.yml

cp .vault_pass.example .vault_pass
chmod 600 .vault_pass
cp group_vars/all/vault.yml.example group_vars/all/vault.yml
ansible-vault encrypt group_vars/all/vault.yml
```

If `inventory.ini` is missing:

```bash
cp inventory.ini.example inventory.ini
nano inventory.ini
```

Confirm the graph:

```bash
ansible-inventory --graph
```

You should see `web`, `app` (same host as `web`), and `db`. The control node is **not** in the inventory.

---

## 8. Classroom commands (run these on the control node)

```bash
cd /home/ubuntu/gitops-linux-platform-with-ansible

ansible all -m ping
ansible web -m command -a "hostname"
ansible db -m command -a "hostname"

ansible-playbook 01-basics.yml
ansible-playbook 02-webserver.yml --check --diff
ansible-playbook 02-webserver.yml
ansible-playbook 02-webserver.yml
```

The second `02-webserver.yml` run should report `changed=0` (idempotent).

From your **laptop** browser or curl, use the **web Elastic IP**:

```bash
curl http://WEB_PUBLIC_IP/
```

You should see “Ansible restored this page”.

---

## 9. Drift demo

SSH to the web managed node (from the laptop or from the control node):

```bash
# from the control node
ssh -i /home/ubuntu/keys/homelab-ec2.pem ubuntu@WEB_PRIVATE_IP
sudo systemctl stop nginx
sudo systemctl is-active nginx
exit
```

Then on the **control node**:

```bash
cd /home/ubuntu/gitops-linux-platform-with-ansible
ansible-playbook 02-webserver.yml
```

Ansible should restore Nginx (`changed=1` on the service task). Check again:

```bash
curl http://WEB_PUBLIC_IP/
```

---

## 10. Capstone — full platform (`site.yml`)

This is the notable project: hardened Ubuntu, Nginx + TLS, FastAPI on `web1`, PostgreSQL + backups on `db1`, health check on `/health`.

```bash
cd /home/ubuntu/gitops-linux-platform-with-ansible

ansible-playbook site.yml --syntax-check
ansible-playbook site.yml
```

Prove it from the control node:

```bash
curl -k https://WEB_PRIVATE_IP/health
ansible-playbook playbooks/check-health.yml
```

From the laptop (web public IP):

```bash
curl -k https://WEB_PUBLIC_IP/health
curl -k https://WEB_PUBLIC_IP/api/notes
curl -k -X POST https://WEB_PUBLIC_IP/api/notes \
  -H 'Content-Type: application/json' \
  -d '{"title":"classroom","body":"platform is up"}'
```

Second run (expect `changed=0`):

```bash
ansible-playbook site.yml
```

Optional:

```bash
ansible-playbook playbooks/backup-now.yml
ansible-playbook playbooks/rolling-deploy.yml
```

---

## 11. Day-2 commands (control node)

```bash
ansible-inventory --graph
ansible all -m ping
ansible web -a "uptime"
ansible-playbook 02-webserver.yml
ansible-playbook site.yml
ansible-playbook site.yml --check --diff
ansible-vault view group_vars/all/vault.yml
ansible-vault edit group_vars/all/vault.yml
```

---

## 12. Destroy the class (laptop)

This deletes the VPC and all three instances.

```bash
cd /media/hazrat/Hazrat4/Code/devops/gitops-linux-platform-with-ansible/terraform/aws
terraform destroy -var-file=terraform.tfvars
```

---

## Troubleshooting

**`Failed to connect ... ssh` from the control node**

```bash
chmod 400 /home/ubuntu/keys/homelab-ec2.pem
ssh -i /home/ubuntu/keys/homelab-ec2.pem ubuntu@WEB_PRIVATE_IP
```

Use **private** IPs in `inventory.ini`. Public IPs work only if the security group allows SSH from the control node’s public IP; private IPs use the VPC.

**`Permission denied (publickey)` onto the control node**

You used the wrong key. Terraform uploaded `~/.ssh/homelab-ec2.pub`. SSH with `~/.ssh/homelab-ec2`.

**Ping timeout from your laptop to port 22**

`allowed_ssh_cidr` is not your current IP. Re-apply:

```bash
curl -s https://checkip.amazonaws.com
# edit terraform.tfvars allowed_ssh_cidr
cd terraform/aws
terraform apply -var-file=terraform.tfvars
```

**`http://WEB_PUBLIC_IP/` does not load**

Run `02-webserver.yml` first. Security group must allow 80. Use the **web** Elastic IP, not the control IP.

**`/health` returns 502/503 after `site.yml`**

`homelab_db_ip` in `inventory.ini` must be the **db private IP**. `homelab_app_ip` stays `127.0.0.1` because the app runs on `web1`.

**Amazon Linux**

Rebuild with Ubuntu 22.04. The classroom playbooks will not work on Amazon Linux.
