# Ansible Classroom Kit (AWS)

Three Ubuntu EC2 instances: **1 control node** + **2 managed nodes**. You install Ansible on the control node, copy the private key there, and run the playbooks from that machine.

| Host | Group | Role |
|------|--------|------|
| `control` | (not in inventory) | Ansible master |
| `web1` | `web` + `app` | Nginx demo, then Nginx + FastAPI |
| `db1` | `db` | PostgreSQL + backups |

Port 22 from your laptop. Port 80 on `web1` for the classroom web page.

**Follow [BUILD-GUIDE.md](BUILD-GUIDE.md).** Every command is there.

## Classroom sequence (on the control node)

```bash
ansible-inventory --graph
ansible all -m ping
ansible web -m command -a "hostname"
ansible-playbook 01-basics.yml
ansible-playbook 02-webserver.yml --check --diff
ansible-playbook 02-webserver.yml
ansible-playbook 02-webserver.yml
```

Drift demo — stop Nginx on `web1`, then rerun `02-webserver.yml`. Ansible restores the service.

Capstone:

```bash
ansible-playbook site.yml
curl -k https://WEB_IP/health
```

## Create the 3 machines (laptop)

```bash
cd terraform/aws
cp example.tfvars terraform.tfvars
# set aws_region, ssh key paths, allowed_ssh_cidr=YOUR_IP/32
terraform init
terraform apply -var-file=terraform.tfvars
terraform output
```

Then SSH to `control_public_ip` and continue in BUILD-GUIDE.md from section 4.

## Layout

```text
01-basics.yml                 # classroom: facts + ping
02-webserver.yml              # classroom: Nginx + drift restore
site.yml                      # capstone: harden + TLS + app + db
inventory.ini.example         # copy to inventory.ini on the control node
terraform/aws/                # 3 EC2 + SGs + inventory.ini
roles/{common,nginx,app,postgres,backup}
```
