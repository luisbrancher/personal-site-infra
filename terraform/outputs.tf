# Exibe o IP público da instância após a criação
output "ip_publico" {
  description = "Endereço IP público da instância EC2"
  value       = aws_instance.server_debian.public_ip
}

