# Development Environment - Layered Architecture

This Terraform configuration deploys a complete DevSecOps platform for development using a **layered architecture** pattern.

## Why Layered Architecture?

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FOUNDATION LAYER                                │
│  • VPC, EKS, ECR, OIDC - Long-lived, rarely changes                    │
│  • Separate state file - Faster plans, isolated blast radius           │
└─────────────────────────────────────────────────────────────────────────┘
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                         ADDONS LAYER                                    │
│  • ArgoCD, K8s manifests - Changes frequently                          │
│  • Reads foundation outputs via data sources                           │
└─────────────────────────────────────────────────────────────────────────┘
```

**Benefits:**
- ⚡ **Faster `terraform plan`** - Each layer only processes its resources
- 🛡️ **Isolated blast radius** - Addon changes can't affect infrastructure
- 🔄 **Independent deployments** - Deploy addons without touching foundation
- 🔗 **Clear dependency chain** - Foundation → Addons

---

## Directory Structure

```
dev/
├── foundation/          # Layer 1: Core infrastructure
│   ├── main.tf         # VPC, EKS, ECR, GitHub OIDC
│   ├── variables.tf    # Foundation variables
│   ├── outputs.tf      # Outputs for addons layer
│   ├── backend.tf      # S3 backend config
│   └── terraform.tfvars.example
│
├── addons/             # Layer 2: Kubernetes addons
│   ├── main.tf         # ArgoCD, EKS GitOps
│   ├── data.tf         # Remote state from foundation
│   ├── variables.tf    # Addon variables
│   ├── outputs.tf      # Addon outputs
│   ├── backend.tf      # S3 backend (different key)
│   └── terraform.tfvars.example
│
└── README.md           # This file
```

---

## Quick Start

### Step 1: Deploy Foundation

```bash
cd foundation/

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and apply
terraform init
terraform plan
terraform apply

# Save outputs for addons
terraform output > output.log
```

### Step 2: Deploy Addons

```bash
cd ../addons/

# Copy and edit variables
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values

# Initialize and apply
terraform init
terraform plan
terraform apply
```

### Step 3: Configure kubectl

```bash
# Get kubeconfig from foundation
cd ../foundation/
$(terraform output -raw configure_kubectl)

# Verify cluster access
kubectl get nodes
kubectl get pods -n argocd
```

---

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
│  ┌───────────────────┐  ┌───────────────────┐  ┌─────────────────────┐ │
│  │   ECR Repository  │  │  GitHub OIDC      │  │  ArgoCD             │ │
│  │   (Container Reg) │  │  (Keyless Auth)   │  │  (GitOps)           │ │
│  └───────────────────┘  └───────────────────┘  └─────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Configuration Reference

### Foundation Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `devsecops` | Project name prefix for resources |
| `environment` | `dev` | Environment name |
| `aws_region` | `us-east-1` | AWS region |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR block |
| `az_count` | `2` | Number of Availability Zones |
| `kubernetes_version` | `1.32` | EKS Kubernetes version |
| `node_instance_types` | `["t3.medium"]` | EC2 instance types |
| `capacity_type` | `SPOT` | ON_DEMAND or SPOT |
| `node_desired_size` | `2` | Desired node count |
| `ecr_repository_name` | `user-service` | ECR repository name |
| `github_org` | `abhishekpanda0620` | GitHub organization |
| `github_repo` | `devsecops-platform-template` | GitHub repository |

### Addons Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | `devsecops` | Must match foundation |
| `environment` | `dev` | Must match foundation |
| `enable_helm_argocd` | `true` | Install ArgoCD via Helm |
| `argocd_namespace` | `argocd` | ArgoCD namespace |
| `deploy_root_application` | `true` | Deploy root app-of-apps |

---

## Upgrading EKS Version

To upgrade EKS (e.g., 1.32 → 1.33):

```bash
cd foundation/

# Update terraform.tfvars
kubernetes_version = "1.33"

# Plan and apply
terraform plan   # Review changes
terraform apply  # Apply upgrade
```

> ⚠️ **Note**: AWS only allows upgrading 1 minor version at a time.

---

## Estimated Costs (Dev Configuration)

| Resource | Monthly Cost (approx) |
|----------|----------------------|
| NAT Gateway (1) | ~$32 |
| EKS Control Plane | ~$72 |
| EC2 SPOT (2x t3.medium) | ~$30-40 |
| ECR | ~$1-5 |
| **Total** | **~$135-150/month** |

---

## Cleanup

**Important:** Destroy in reverse order!

```bash
# Step 1: Destroy addons first
cd addons/
terraform destroy

# Step 2: Destroy foundation
cd ../foundation/
terraform destroy
```

---

## Troubleshooting

### Remote State Not Found (Addons)

Ensure foundation has been applied first and outputs exist:
```bash
cd foundation/
terraform output
```

### EKS Nodes Not Joining

1. Check security groups allow node-to-control-plane communication
2. Verify private subnets have NAT Gateway route
3. Check node IAM role has required policies

### ArgoCD Not Syncing

1. Verify GitOps repository is accessible
2. Check ArgoCD is running: `kubectl get pods -n argocd`
3. Check application status: `kubectl get applications -n argocd`
