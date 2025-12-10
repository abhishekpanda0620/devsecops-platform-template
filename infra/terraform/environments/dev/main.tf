# Development Environment Configuration
# This is an example environment setup for local testing

terraform {
  required_version = ">= 1.12.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Uncomment for remote state
  # backend "s3" {
  #   bucket         = "your-terraform-state-bucket"
  #   key            = "devsecops/dev/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "dev"
      Project     = "devsecops-platform"
      ManagedBy   = "terraform"
    }
  }
}

# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

# Data sources for existing VPC (or create new one)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# EKS Cluster
module "eks" {
  source = "../../modules/eks"

  cluster_name       = "devsecops-${var.environment}"
  kubernetes_version = "1.34"

  vpc_id     = data.aws_vpc.default.id
  subnet_ids = data.aws_subnets.default.ids

  # Security settings
  endpoint_private_access   = true
  endpoint_public_access    = true
  public_access_cidrs       = ["0.0.0.0/0"]  # Restrict in production
  enable_secrets_encryption = true

  # Logging
  enabled_cluster_log_types = ["api", "audit"]
  log_retention_days        = 7

  # Node configuration
  node_instance_types = ["t3.medium"]
  node_desired_size   = 2
  node_min_size       = 1
  node_max_size       = 3
  node_disk_size      = 30
  capacity_type       = "SPOT"  # Use SPOT for dev to save costs

  node_labels = {
    environment = var.environment
    workload    = "general"
  }

  tags = {
    Environment = var.environment
    CostCenter  = "development"
  }
}

# Outputs
output "cluster_endpoint" {
  description = "EKS cluster endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks.cluster_name
}

output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}
