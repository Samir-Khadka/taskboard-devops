provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
    }
  }
}

# ---------------------------------------------------------------------------
# Networking: VPC, public subnet, internet gateway, route table
# ---------------------------------------------------------------------------

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Security group
#   22          SSH, admin CIDR only
#   80 / 443    HTTP(S), public (front door for a future reverse proxy / ALB)
#   8080        TaskBoard web UI (docker compose), public
#   3001 / 9090 Grafana / Prometheus — admin CIDR only, they are admin tools
# ---------------------------------------------------------------------------

resource "aws_security_group" "host" {
  name        = "${var.project}-host"
  description = "TaskBoard host: SSH + web from restricted/public CIDRs as noted per rule."
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "TaskBoard web UI (docker compose)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Grafana from admin CIDR"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "Prometheus from admin CIDR"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-host-sg"
  }
}

# ---------------------------------------------------------------------------
# Compute: one Ubuntu 22.04 host that bootstraps Docker + the compose stack
# ---------------------------------------------------------------------------

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "host" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.host.id]
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail
    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y ca-certificates curl git

    # Docker Engine + Compose plugin (official convenience script; for a
    # hardened setup prefer Docker's apt repository with pinned versions).
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    usermod -aG docker ubuntu

    # Clone and start the stack. Ansible (ansible/playbook.yml) can take
    # over configuration management from here.
    if [ ! -d /home/ubuntu/taskboard-devops ]; then
      git clone ${var.repo_url} /home/ubuntu/taskboard-devops
    fi
    cd /home/ubuntu/taskboard-devops
    cp -n .env.example .env || true
    chown -R ubuntu:ubuntu /home/ubuntu/taskboard-devops
    sudo -u ubuntu docker compose up -d --build
  EOF

  tags = {
    Name = "${var.project}-host"
  }
}

resource "aws_eip" "host" {
  instance = aws_instance.host.id
  domain   = "vpc"

  tags = {
    Name = "${var.project}-eip"
  }
}
