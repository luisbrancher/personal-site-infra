variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "sa-east-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.micro"
}

variable "project_name" {
  description = "Used for tagging and naming resources"
  type        = string
  default     = "debian-server"
}

variable "ssh_public_key" {
  description = "ED25519 public key for SSH access"
  type        = string
  sensitive   = true
}