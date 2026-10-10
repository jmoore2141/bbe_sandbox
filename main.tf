terraform {
  required_version = ">= 1.6, < 2.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region              = "us-east-1"
  allowed_account_ids = [var.aws_account_id]
  default_tags {
    tags = { Project = "bbe-private-ec2-demo", ManagedBy = "Terraform" }
  }
}

variable "aws_account_id" {
  description = "Expected AWS account ID; provider refuses to use another account."
  type        = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Provide a 12-digit AWS account ID."
  }
}

variable "instance_type" {
  description = "Small x86_64 instance; confirm pricing/credit eligibility for your account."
  type        = string
  default     = "t3.micro"
}

data "aws_ssm_parameter" "ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_vpc" "demo" {
  cidr_block           = "10.42.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "bbe-demo" }
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.demo.id
  cidr_block              = "10.42.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = false
  tags                    = { Name = "bbe-demo-private" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.demo.id
  # Only the automatic VPC-local route; no internet or NAT route.
  tags = { Name = "bbe-demo-private" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "isolated" {
  name_prefix = "bbe-demo-isolated-"
  description = "No inbound or outbound rules for the isolated demo"
  vpc_id      = aws_vpc.demo.id
  ingress     = []
  egress      = []
}

resource "aws_instance" "demo" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ami.value)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.isolated.id]
  associate_public_ip_address = false

  credit_specification {
    cpu_credits = "standard"
  }
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8
    encrypted             = true
    delete_on_termination = true
  }
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }
  tags = { Name = "bbe-demo-private-ec2" }
}

output "instance_id" {
  value = aws_instance.demo.id
}
output "private_ip" {
  value = aws_instance.demo.private_ip
}
output "vpc_id" {
  value = aws_vpc.demo.id
}
