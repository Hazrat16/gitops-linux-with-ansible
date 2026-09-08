data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "homelab" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_prefix}-vpc"
  }
}

resource "aws_internet_gateway" "homelab" {
  vpc_id = aws_vpc.homelab.id

  tags = {
    Name = "${var.project_prefix}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.homelab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_prefix}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.homelab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.homelab.id
  }

  tags = {
    Name = "${var.project_prefix}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "control" {
  name        = "${var.project_prefix}-control"
  description = "Ansible control node — SSH from the instructor"
  vpc_id      = aws_vpc.homelab.id

  ingress {
    description = "SSH from instructor"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "web" {
  name        = "${var.project_prefix}-web"
  description = "Managed web node — SSH plus HTTP demo"
  vpc_id      = aws_vpc.homelab.id

  ingress {
    description = "SSH from instructor"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description     = "SSH from control node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.control.id]
  }

  ingress {
    description = "HTTP classroom demo"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_prefix}-db"
  description = "Managed db node — SSH plus PostgreSQL from web"
  vpc_id      = aws_vpc.homelab.id

  ingress {
    description = "SSH from instructor"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description     = "SSH from control node"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.control.id]
  }

  ingress {
    description     = "PostgreSQL from web (app lives on web)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
