# Registro A apontando pro IP da EC2
resource "cloudflare_record" "site" {
  zone_id = "72c9a894daa53ba6b5e9a3ea854cf6ac"
  name    = "@"
  content = aws_instance.server_debian.public_ip
  type    = "A"
  proxied = true
  ttl     = 1  # 1 = automático quando proxied = true
}

# www redireciona pra raiz
resource "cloudflare_record" "www" {
  zone_id = "72c9a894daa53ba6b5e9a3ea854cf6ac"
  name    = "www"
  content = aws_instance.server_debian.public_ip
  type    = "A"
  proxied = true
  ttl     = 1
}