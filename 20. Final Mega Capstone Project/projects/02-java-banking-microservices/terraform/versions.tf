terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
  # Configure an encrypted, versioned, locked S3 backend before team use.
}

provider "aws" {
  region = var.aws_region
  default_tags { tags = local.tags }
}
