output "control_public_ip" {
  value       = aws_eip.control.public_ip
  description = "SSH here and run Ansible"
}

output "web_public_ip" {
  value       = aws_eip.web.public_ip
  description = "Classroom HTTP demo — http://THIS_IP/"
}

output "db_public_ip" {
  value = aws_instance.nodes["db1"].public_ip
}

output "private_ips" {
  value = {
    control = aws_instance.nodes["control"].private_ip
    web1    = aws_instance.nodes["web1"].private_ip
    db1     = aws_instance.nodes["db1"].private_ip
  }
}

output "ssh_control" {
  value = "ssh -i ${pathexpand(var.ssh_private_key_path)} ubuntu@${aws_eip.control.public_ip}"
}

output "inventory_file" {
  value = "inventory.ini"
}
