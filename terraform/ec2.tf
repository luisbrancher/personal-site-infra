# cria par de chaves para SSH
resource "aws_key_pair" "chave_ssh" {
  key_name   = "chave-debian-server"
  public_key = file(pathexpand("~/.ssh/id_ed25519.pub"))
}

# acha a imagem oficial mais recente do Debian 13 ARM
data "aws_ami" "debian" {
  most_recent = true
  owners      = ["136693071363"] # ID Debian AWS

  filter {
    name   = "name"
    values = ["debian-13-arm64-*"] # filtra por Debian 13 ARM
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# create EC2 instances
resource "aws_instance" "server_debian" {

  ami           = data.aws_ami.debian.id # pega a AMI do debian encontrdo pelo bloco acima
  instance_type = var.instance_type      # free tier arm

  # adiciona na VPC criada
  subnet_id              = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # hardening - desativa SSH com senha e root
  user_data = <<-EOF
          #!/bin/bash
          set -e

          sed -i 's/^#\\?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
          sed -i 's/^#\\?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
          sed -i 's/^#\\?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

          systemctl enable ssh
          systemctl restart ssh || systemctl restart sshd
          EOF

  key_name = aws_key_pair.chave_ssh.key_name # atribui a chave SSH

  # pega ip publico
  associate_public_ip_address = true

  # tag para facilitar a identificação
  tags = {
    Name = "EC2-${var.project_name}"
  }
}