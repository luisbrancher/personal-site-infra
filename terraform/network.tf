# cria main VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true # para dominio .dev

  tags = { Name = "VPC-${var.project_name}" }
}

# cria a subnet pública
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.main_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = { Name = "subnet-${var.project_name}" }
}

# cria gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = { Name = "IGW-${var.project_name}" }
}

# route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = { Name = "rota-publica${var.project_name}" }
}

# linka subnet a route table
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# IPs Cloudflare (cloudflare.com/ips)
locals {
  cloudflare_ips = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22"
  ]
}

# Security Group para liberar o tráfego do site
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg-" #name_prefix evita conflito de nomes
  description = "Acesso seguro para dominio .dev"
  vpc_id      = aws_vpc.main_vpc.id # vincula o SG a VPC

  # HTTPS (dasativado por usar porta 80 cloudflare - AWS)
#  ingress {
#    from_port   = 443
#    to_port     = 443
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]
#  }

  # HTTP - apenas IPs do Cloudflare
  dynamic "ingress" {
    for_each = local.cloudflare_ips
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  # SSH

  dynamic "ingress" {
    for_each = var.enable_ssh ? [1] : [] # variavel bool pra abrir ou não a porta
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # Migrar para tailscale | usando global pois codei em viagem e nao possuia IP fixo
    }
  }

  # server can access the web
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
