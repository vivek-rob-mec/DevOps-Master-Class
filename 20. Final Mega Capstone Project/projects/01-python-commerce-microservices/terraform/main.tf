locals {
  name = "${var.project_name}-${var.environment}"
  tags = merge(var.tags, {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Template    = "01-python-commerce-microservices"
  })
}

data "aws_availability_zones" "available" { state = "available" }

module "vpc" {
  source                 = "terraform-aws-modules/vpc/aws"
  version                = "~> 6.0"
  name                   = local.name
  cidr                   = var.vpc_cidr
  azs                    = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets        = [for i in range(3) : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets         = [for i in range(3) : cidrsubnet(var.vpc_cidr, 8, i + 48)]
  database_subnets       = [for i in range(3) : cidrsubnet(var.vpc_cidr, 8, i + 64)]
  enable_nat_gateway     = true
  single_nat_gateway     = var.environment != "prod"
  one_nat_gateway_per_az = var.environment == "prod"
  enable_dns_hostnames   = true
  public_subnet_tags     = { "kubernetes.io/role/elb" = "1" }
  private_subnet_tags    = { "kubernetes.io/role/internal-elb" = "1" }
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = "~> 21.0"
  name                                     = local.name
  kubernetes_version                       = var.kubernetes_version
  endpoint_public_access                   = var.cluster_endpoint_public_access
  enable_cluster_creator_admin_permissions = true
  deletion_protection                      = var.environment == "prod"
  enabled_log_types                        = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  upgrade_policy                           = { support_type = "STANDARD" }
  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  addons = {
    coredns            = { most_recent = true }
    kube-proxy         = { most_recent = true }
    vpc-cni            = { most_recent = true }
    aws-ebs-csi-driver = { most_recent = true }
  }
  eks_managed_node_groups = {
    application = {
      instance_types = var.node_instance_types
      min_size       = 2
      max_size       = 6
      desired_size   = 3
      capacity_type  = "ON_DEMAND"
    }
  }
}

resource "aws_ecr_repository" "workload" {
  for_each             = toset(var.workloads)
  name                 = "${var.project_name}-${each.value}"
  image_tag_mutability = "IMMUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
}

resource "aws_db_subnet_group" "app" {
  count      = var.create_postgres ? 1 : 0
  name       = local.name
  subnet_ids = module.vpc.database_subnets
}

resource "aws_security_group" "postgres" {
  count       = var.create_postgres ? 1 : 0
  name_prefix = "${local.name}-db-"
  vpc_id      = module.vpc.vpc_id
  ingress {
    protocol        = "tcp"
    from_port       = 5432
    to_port         = 5432
    security_groups = [module.eks.node_security_group_id]
  }
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "app" {
  count                       = var.create_postgres ? 1 : 0
  identifier                  = local.name
  engine                      = "postgres"
  instance_class              = var.postgres_instance_class
  allocated_storage           = 20
  max_allocated_storage       = 100
  storage_type                = "gp3"
  storage_encrypted           = true
  db_name                     = "app"
  username                    = "platform_admin"
  manage_master_user_password = true
  publicly_accessible         = false
  multi_az                    = var.environment == "prod"
  backup_retention_period     = var.environment == "prod" ? 14 : 3
  deletion_protection         = var.environment == "prod"
  skip_final_snapshot         = var.environment != "prod"
  final_snapshot_identifier   = var.environment == "prod" ? "${local.name}-final" : null
  db_subnet_group_name        = aws_db_subnet_group.app[0].name
  vpc_security_group_ids      = [aws_security_group.postgres[0].id]
}
