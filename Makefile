.PHONY: collections lint yamllint syntax ping basics web deploy health backup \
	rolling ci aws-apply aws-destroy

collections:
	ansible-galaxy collection install -r requirements.yml

lint:
	ansible-lint

yamllint:
	yamllint .

syntax:
	ansible-playbook 01-basics.yml --syntax-check
	ansible-playbook 02-webserver.yml --syntax-check
	ansible-playbook site.yml --syntax-check
	ansible-playbook playbooks/rolling-deploy.yml --syntax-check
	ansible-playbook playbooks/backup-now.yml --syntax-check
	ansible-playbook playbooks/check-health.yml --syntax-check

ping:
	ansible all -m ping

basics:
	ansible-playbook 01-basics.yml

web:
	ansible-playbook 02-webserver.yml

deploy:
	ansible-playbook site.yml

health:
	ansible-playbook playbooks/check-health.yml

backup:
	ansible-playbook playbooks/backup-now.yml

rolling:
	ansible-playbook playbooks/rolling-deploy.yml

ci: yamllint lint syntax

aws-apply:
	cd terraform/aws && terraform apply -var-file=terraform.tfvars

aws-destroy:
	cd terraform/aws && terraform destroy -var-file=terraform.tfvars
