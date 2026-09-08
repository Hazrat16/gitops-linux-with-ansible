data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_key_pair" "homelab" {
  key_name   = "${var.project_prefix}-ansible"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

locals {
  nodes = {
    control = {
      role = "control"
      sg   = aws_security_group.control.id
    }
    web1 = {
      role = "web"
      sg   = aws_security_group.web.id
    }
    db1 = {
      role = "db"
      sg   = aws_security_group.db.id
    }
  }
}

resource "aws_instance" "nodes" {
  for_each = local.nodes

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [each.value.sg]
  key_name                    = aws_key_pair.homelab.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/../../cloud-init/user-data.yaml")

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "${var.project_prefix}-${each.key}"
    Role = each.value.role
  }
}

resource "aws_eip" "control" {
  instance = aws_instance.nodes["control"].id
  domain   = "vpc"

  tags = {
    Name = "${var.project_prefix}-control"
  }
}

resource "aws_eip" "web" {
  instance = aws_instance.nodes["web1"].id
  domain   = "vpc"

  tags = {
    Name = "${var.project_prefix}-web"
  }
}

resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../../inventory.ini"
  content = templatefile("${path.module}/inventory.ini.tftpl", {
    web_private_ip = aws_instance.nodes["web1"].private_ip
    db_private_ip  = aws_instance.nodes["db1"].private_ip
  })
}
