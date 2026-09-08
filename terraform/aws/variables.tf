variable "aws_region" {
  type        = string
  default     = "us-east-1"
  description = "AWS region for the VPC and EC2 instances"
}

variable "project_prefix" {
  type        = string
  default     = "homelab"
}

variable "instance_type" {
  type        = string
  default     = "t3.small"
}

variable "ssh_public_key_path" {
  type        = string
  description = "Path to the public key uploaded as the EC2 key pair (matching private key is used by Ansible)"
}

variable "ssh_private_key_path" {
  type        = string
  description = "Local private key path (shown in terraform output ssh_control)"
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH. Prefer YOUR_PUBLIC_IP/32."
}

variable "allowed_http_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to reach web :80 and :443"
}

variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}

variable "public_subnet_cidr" {
  type    = string
  default = "10.42.1.0/24"
}
