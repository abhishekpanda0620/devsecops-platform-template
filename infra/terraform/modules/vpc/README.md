# Enterprise VPC Module for EKS

This Terraform module creates a production-ready VPC for Amazon EKS based on AWS best practices.

## Architecture

```
                                 ┌─────────────────────────────────────────┐
                                 │              INTERNET                   │
                                 └──────────────────┬──────────────────────┘
                                                    │
                                 ┌──────────────────▼──────────────────────┐
                                 │          Internet Gateway               │
                                 └──────────────────┬──────────────────────┘
                                                    │
┌───────────────────────────────────────────────────┴───────────────────────────────────────────────────┐
│                                              VPC (10.0.0.0/16)                                         │
├───────────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                       │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐                        │
│   │   Public Subnet     │   │   Public Subnet     │   │   Public Subnet     │                        │
│   │   10.0.0.0/20       │   │   10.0.16.0/20      │   │   10.0.32.0/20      │   ← ALB, Bastion       │
│   │   AZ-a              │   │   AZ-b              │   │   AZ-c              │                        │
│   │   ┌──────────────┐  │   │   ┌──────────────┐  │   │   ┌──────────────┐  │                        │
│   │   │  NAT Gateway │  │   │   │  NAT Gateway │  │   │   │  NAT Gateway │  │                        │
│   │   └──────┬───────┘  │   │   └──────┬───────┘  │   │   └──────┬───────┘  │                        │
│   └──────────┼──────────┘   └──────────┼──────────┘   └──────────┼──────────┘                        │
│              │                         │                         │                                    │
│              ▼                         ▼                         ▼                                    │
│   ┌─────────────────────┐   ┌─────────────────────┐   ┌─────────────────────┐                        │
│   │   Private Subnet    │   │   Private Subnet    │   │   Private Subnet    │                        │
│   │   10.0.64.0/18      │   │   10.0.128.0/18     │   │   10.0.192.0/18     │   ← EKS Nodes, DBs     │
│   │   AZ-a              │   │   AZ-b              │   │   AZ-c              │                        │
│   │                     │   │                     │   │                     │                        │
│   └─────────────────────┘   └─────────────────────┘   └─────────────────────┘                        │
│                                                                                                       │
│   ┌─────────────────────────────────────────────────────────────────────────────────────────────┐    │
│   │                                    VPC Endpoints (Optional)                                  │    │
│   │   • S3 (Gateway)  • ECR API/DKR  • EC2  • STS  • CloudWatch Logs                            │    │
│   └─────────────────────────────────────────────────────────────────────────────────────────────┘    │
│                                                                                                       │
└───────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Features

### Security Best Practices
- ✅ EKS nodes in private subnets (no public IPs)
- ✅ NAT Gateway for controlled outbound access
- ✅ VPC Flow Logs for monitoring
- ✅ VPC Endpoints for private AWS service access

### High Availability
- ✅ Multi-AZ deployment (3 AZs recommended)
- ✅ One NAT Gateway per AZ (production)
- ✅ Subnet per AZ for fault tolerance

### EKS Optimized
- ✅ Proper Kubernetes subnet tagging
- ✅ Generous IP allocation (/18 for private subnets = 16,384 IPs)
- ✅ DNS hostname and resolution enabled

## Usage

### Production Environment

```hcl
module "vpc" {
  source = "./infra/terraform/modules/vpc"

  cluster_name = "my-eks-cluster"
  vpc_cidr     = "10.0.0.0/16"
  az_count     = 3

  # Production settings
  single_nat_gateway   = false  # One NAT GW per AZ
  enable_vpc_endpoints = true   # For private cluster support
  enable_flow_logs     = true   # For compliance

  tags = {
    Environment = "production"
    ManagedBy   = "terraform"
  }
}

module "eks" {
  source = "./infra/terraform/modules/eks"

  cluster_name = "my-eks-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids  # Use private subnets!

  # ... other EKS config
}
```

### Development Environment (Cost Optimized)

```hcl
module "vpc" {
  source = "./infra/terraform/modules/vpc"

  cluster_name = "my-eks-dev"
  vpc_cidr     = "10.1.0.0/16"
  az_count     = 2  # Minimum for EKS

  # Cost savings for dev
  single_nat_gateway   = true   # Single NAT GW (not HA)
  enable_vpc_endpoints = false  # Use NAT GW instead
  enable_flow_logs     = false  # Disable for dev

  tags = {
    Environment = "development"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name for resource naming and EKS tagging | `string` | n/a | yes |
| vpc_cidr | VPC CIDR block (recommended: /16) | `string` | `"10.0.0.0/16"` | no |
| az_count | Number of Availability Zones (2-6) | `number` | `3` | no |
| single_nat_gateway | Use single NAT GW (dev) vs one per AZ (prod) | `bool` | `false` | no |
| enable_vpc_endpoints | Enable VPC endpoints for AWS services | `bool` | `false` | no |
| enable_flow_logs | Enable VPC Flow Logs | `bool` | `true` | no |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| private_subnet_ids | List of private subnet IDs (for EKS nodes) |
| public_subnet_ids | List of public subnet IDs (for ALB/NLB) |
| nat_gateway_ips | List of NAT Gateway public IPs |

## Subnet Sizing

For a `/16` VPC (65,536 IPs):

| Subnet Type | CIDR | IPs per Subnet | Total IPs | Purpose |
|-------------|------|----------------|-----------|---------|
| Public | /20 | 4,096 | 12,288 (3 AZs) | ALB, NLB, Bastion |
| Private | /18 | 16,384 | 49,152 (3 AZs) | EKS nodes, DBs |

## Cost Considerations

| Component | Dev (Single NAT) | Prod (3 NAT GWs) |
|-----------|------------------|------------------|
| NAT Gateway | ~$32/month | ~$96/month |
| VPC Endpoints (6) | $0 | ~$44/month |
| Data Transfer | Variable | Variable |

## References

- [EKS VPC Requirements](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)
- [EKS Best Practices - VPC Design](https://aws.github.io/aws-eks-best-practices/networking/vpc-design/)
- [EKS Subnet Tagging](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html)
