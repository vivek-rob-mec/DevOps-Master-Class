provider "aws" {
  region = var.aws_region
}
data "aws_availability_zones" "available" { state = "available" }
locals {
  name = "${var.project_name}-${var.environment}"
}
module "vpc" {
  source             = "terraform-aws-modules/vpc/aws"
  version            = "~> 6.0"
  name               = local.name
  cidr               = var.vpc_cidr
  azs                = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets    = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets     = [for i in range(3) : cidrsubnet(var.vpc_cidr, 8, i + 48)]
  enable_nat_gateway = true
  single_nat_gateway = var.environment != "prod"
}
module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 21.0"
  name                                     = local.name
  kubernetes_version                       = "1.36"
  endpoint_public_access                   = false
  enable_cluster_creator_admin_permissions = true
  deletion_protection                      = var.environment == "prod"
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  eks_managed_node_groups = {
    platform = {
      instance_types = ["m7i.large"]
      min_size       = 2
      max_size       = 6
      desired_size   = 3
    }
  }
}
