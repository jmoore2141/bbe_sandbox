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
  tags                    = { Name = "bbe-demo-web" }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.demo.id
  tags   = { Name = "bbe-demo-web" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_security_group" "isolated" {
  name_prefix = "bbe-demo-isolated-"
  description = "HTTP and SSH from the configured client IP"
  vpc_id      = aws_vpc.demo.id
  ingress {
    description = "SSH from client"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.client_cidr]
  }
  ingress {
    description = "HTTP from client"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.client_cidr]
  }
  egress {
    description = "Package downloads over HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description = "Package downloads over HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "demo" {
  ami                         = nonsensitive(data.aws_ssm_parameter.ami.value)
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.isolated.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.demo.key_name
  user_data                   = file("${path.module}/webserver.sh")
  user_data_replace_on_change = true
  depends_on                  = [aws_route.internet, aws_route_table_association.private]

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
  tags = { Name = "bbe-demo-web-ec2" }
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

variable "client_cidr" {
  description = "Your public IPv4 address as a /32; allowed to use SSH and HTTP."
  type        = string
  validation {
    condition     = can(cidrnetmask(var.client_cidr)) && can(regex("/32$", var.client_cidr))
    error_message = "Use one IPv4 address with a /32 prefix."
  }
}

resource "aws_internet_gateway" "demo" {
  vpc_id = aws_vpc.demo.id
  tags   = { Name = "bbe-demo-web" }
}
resource "aws_route" "internet" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.demo.id
}
resource "aws_key_pair" "demo" {
  key_name   = "bbe-sandbox-web"
  public_key = file("${path.module}/.keys/bbe-sandbox.pem.pub")
}
output "web_url" {
  value = "http://${aws_instance.demo.public_ip}"
}
output "ssh_command" {
  value = "ssh -i .keys/bbe-sandbox.pem ec2-user@${aws_instance.demo.public_ip}"
}
