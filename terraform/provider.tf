terraform {
  # define local para o .tfstate
  cloud {
    organization = "lfck" # armazenamento do estado no HCP Terraform

    workspaces {
      name = "aws-debian-site"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.2.0"
}

# set AWS provider
provider "aws" {
  region = var.aws_region # Região AZ

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Project   = "meusite.dev"
      Owner     = "luisfuck"
    }
  }
}