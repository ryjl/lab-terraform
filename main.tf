terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "key_name" {
  description = "EC2 key pair(Step2 建的 lab-key;若已清掉见 STEP12 的 12.0 重建)"
  type        = string
  default     = "lab-key"
}

# ── 网络层:和 Step6 的 CF 模板同一个架构(VPC+subnet+IGW+路由+SG) ──
# CIDR 用 10.2.0.0/16,避开 Step1(10.0)和 Step6(10.1)的 VPC

resource "aws_vpc" "main" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "lab-tf-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.2.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags                    = { Name = "lab-tf-subnet" }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "lab-tf-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = { Name = "lab-tf-rt" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "ssh" {
  name        = "lab-tf-sg"
  description = "allow ssh"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lab-tf-sg" }
}

# ── AMI:动态查最新的 Amazon Linux 2023(不用硬编码 AMI id,同 CF 的 {{resolve:ssm}} 思路) ──

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "web" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh.id]
  key_name               = var.key_name
  tags                   = { Name = "lab-tf-ec2", Owner = "v2" }
}

output "public_ip" {
  description = "SSH 用:ssh -i lab-key.pem ec2-user@<这个值>"
  value       = aws_instance.web.public_ip
}
