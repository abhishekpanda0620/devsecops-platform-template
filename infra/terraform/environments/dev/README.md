# Development Environment

This Terraform configuration deploys a complete DevSecOps platform for development.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         AWS Account                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    VPC (10.0.0.0/16)                                │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                        │ │
│  │  │  Public Subnet   │  │  Public Subnet   │  ← ALB, NAT Gateway    │ │
│  │  │  AZ-a            │  │  AZ-b            │                        │ │
│  │  └────────┬─────────┘  └────────┬─────────┘                        │ │
│  │           │ NAT                  │ NAT                              │ │
│  │           ▼                      ▼                                  │ │
│  │  ┌──────────────────┐  ┌──────────────────┐                        │ │
│  │  │  Private Subnet  │  │  Private Subnet  │  ← EKS Nodes           │ │
│  │  │  AZ-a            │  │  AZ-b            │                        │ │
│  │  │  ┌────────────┐  │  │  ┌────────────┐  │                        │ │
│  │  │  │ EKS Node   │  │  │  │ EKS Node   │  │                        │ │
│  │  │  │ (SPOT)     │  │  │  │ (SPOT)     │  │                        │ │
│  │  │  └────────────┘  │  │  └────────────┘  │                        │ │
│  │  └──────────────────┘  └──────────────────┘                        │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    EKS Control Plane                                │ │
│  │  • Kubernetes 1.32                                                  │ │
│  │  • Secrets Encryption (KMS)                                         │ │
│  │  • OIDC Provider (IRSA)                                             │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    GitOps (ArgoCD)                                  │ │
│  │  • Helm-based (default) or AWS Managed                              │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Files

| File | Description |
|------|-------------|
| `main.tf` | Main Terraform configuration - modules and resources |
| `variables.tf` | All input variables with defaults for dev |
| `outputs.tf` | All outputs including deployment summary |

## Quick Start

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply (creates ~15 resources)
terraform apply

# Get kubectl config
$(terraform output -raw configure_kubectl)

# Check cluster
kubectl get nodes
```

## Configuration Options

### VPC Options

| Variable | Default | Description |
|----------|---------|-------------|
| `use_custom_vpc` | `true` | Use enterprise VPC (recommended) |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `2` | Number of Availability Zones |
| `single_nat_gateway` | `true` | Single NAT GW (cost saving for dev) |

### EKS Options

| Variable | Default | Description |
|----------|---------|-------------|
| `kubernetes_version` | `1.32` | EKS Kubernetes version |
| `node_instance_types` | `["t3.medium"]` | EC2 instance types |
| `capacity_type` | `SPOT` | ON_DEMAND or SPOT |
| `node_desired_size` | `2` | Desired node count |

### GitOps Options

| Variable | Default | Description |
|----------|---------|-------------|
| `enable_helm_argocd` | `true` | Install ArgoCD via Helm |
| `enable_aws_managed_gitops` | `false` | AWS Managed ArgoCD (requires Identity Center) |

## Usage Examples

### Default (Recommended for Dev)

```bash
terraform apply
```

### Quick Test with Default VPC

```bash
terraform apply -var="use_custom_vpc=false"
```

### Production-like Setup

```bash
terraform apply \
  -var="az_count=3" \
  -var="single_nat_gateway=false" \
  -var="capacity_type=ON_DEMAND" \
  -var="node_desired_size=3"
```

### With AWS Managed ArgoCD

```bash
terraform apply -var="enable_aws_managed_gitops=true"
# Then follow the output instructions to create the EKS Capability
```

## Estimated Costs (Dev Configuration)

| Resource | Monthly Cost (approx) |
|----------|----------------------|
| NAT Gateway (1) | ~$32 |
| EKS Control Plane | ~$72 |
| EC2 SPOT (2x t3.medium) | ~$30-40 |
| **Total** | **~$134-144/month** |

## Cleanup

```bash
terraform destroy
```

## Troubleshooting

### EKS nodes not joining

1. Check security groups allow node-to-control-plane communication
2. Verify private subnets have NAT Gateway route
3. Check node IAM role has required policies

### ArgoCD not syncing

1. Verify GitOps repository is accessible
2. Check ArgoCD is running: `kubectl get pods -n argocd`
3. Check application status: `kubectl get applications -n argocd`
