# AWS EKS GitOps Module

This Terraform module provides GitOps capabilities for Amazon EKS clusters, supporting both:

1. **AWS EKS Managed Argo CD** (EKS Capability) - Fully managed by AWS
2. **Helm-based ArgoCD** (Self-Managed) - Traditional self-managed installation

## Important Notes

### AWS EKS Managed Argo CD

Based on [official AWS documentation](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html):

- **EKS Managed Argo CD is an "EKS Capability"**, NOT an EKS Addon
- **Terraform does not have native support** for EKS Capabilities yet
- **AWS Identity Center (SSO) is REQUIRED** - local users are NOT supported
- Created via `aws eks create-capability` CLI command, AWS Console, or `eksctl`

This module creates the **IAM Capability Role** required for EKS Managed ArgoCD and provides the CLI command to create the capability.

### Helm-based ArgoCD (Self-Managed)

For environments without AWS Identity Center or for multi-cloud deployments:

- Uses the official ArgoCD Helm chart
- Standard username/password authentication
- Full customization control
- Works on any Kubernetes cluster

## Prerequisites

### For AWS EKS Managed Argo CD

1. **AWS Identity Center configured** - [Getting started guide](https://docs.aws.amazon.com/singlesignon/latest/userguide/getting-started.html)
2. **Users/Groups created in Identity Center** - For RBAC mapping
3. **EKS cluster running a supported Kubernetes version**

### For Helm-based ArgoCD

1. **EKS cluster with kubectl access**
2. **Helm provider configured in Terraform**

## Usage

### Option 1: AWS EKS Managed Argo CD (Recommended for AWS-only)

```hcl
module "eks_gitops" {
  source = "./infra/terraform/modules/eks-gitops"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # Create IAM role for EKS Managed ArgoCD
  enable_managed_argocd = true

  # Disable Helm-based ArgoCD (mutually exclusive)
  enable_helm_argocd = false

  # Optional integrations
  enable_secrets_manager_integration  = true
  enable_codeconnections_integration  = true
  codeconnections_arn                 = "arn:aws:codeconnections:..."

  tags = var.tags
}

# After terraform apply, run the output command to create the capability
# terraform output -raw create_capability_command
```

After running `terraform apply`:

```bash
# Get the CLI command to create the capability
terraform output -raw create_capability_command

# Run the command (requires AWS Identity Center setup)
# The command will be displayed with placeholders to fill in
```

### Option 2: Helm-based ArgoCD (Self-Managed)

```hcl
module "eks_gitops" {
  source = "./infra/terraform/modules/eks-gitops"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # Disable AWS Managed ArgoCD
  enable_managed_argocd = false

  # Enable Helm-based ArgoCD
  enable_helm_argocd = true
  argocd_helm_version = "5.51.6"
  argocd_service_type = "ClusterIP"

  # Deploy root application
  deploy_root_application = true
  gitops_repo_url         = "https://github.com/your-org/your-repo.git"
  gitops_target_revision  = "main"
  gitops_apps_path        = "infra/argocd/apps"

  tags = var.tags
}
```

### Option 3: Both (For Migration or Testing)

```hcl
module "eks_gitops" {
  source = "./infra/terraform/modules/eks-gitops"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  # Enable both (IAM role for managed + Helm for self-managed)
  enable_managed_argocd = true
  enable_helm_argocd    = true

  tags = var.tags
}
```

## Comparison: AWS Managed vs Helm-based (Self-Managed)

| Feature | AWS EKS Managed Argo CD | Helm-based ArgoCD |
|---------|-------------------------|-------------------|
| **Installation** | `aws eks create-capability` | Helm chart |
| **Management** | AWS handles upgrades/patches | You manage |
| **Authentication** | AWS Identity Center (SSO) only | Any (OIDC, LDAP, local) |
| **Infrastructure** | Runs in AWS control plane | Runs on worker nodes |
| **Terraform Support** | IAM role only (capability via CLI) | Full support |
| **Multi-cloud** | ❌ AWS only | ✅ Any Kubernetes |
| **Cost** | Included in EKS | Free (OSS) + compute |
| **Prerequisites** | Identity Center required | None |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| cluster_name | Name of the EKS cluster | `string` | n/a | yes |
| oidc_provider_arn | ARN of the OIDC provider | `string` | n/a | yes |
| oidc_provider_url | URL of the OIDC provider | `string` | n/a | yes |
| enable_managed_argocd | Create IAM role for EKS Managed Argo CD | `bool` | `false` | no |
| enable_helm_argocd | Install ArgoCD via Helm | `bool` | `true` | no |
| enable_ack | Enable ACK controllers | `bool` | `false` | no |
| enable_kro | Enable KRO | `bool` | `false` | no |
| gitops_repo_url | GitOps repository URL | `string` | `"..."` | no |

## Outputs

| Name | Description |
|------|-------------|
| argocd_capability_role_arn | IAM Role ARN for EKS Managed Argo CD |
| create_capability_command | AWS CLI command to create the capability |
| ack_role_arn | IAM Role ARN for ACK controllers |
| next_steps | Instructions for completing setup |

## AWS CLI Commands Reference

### Create Argo CD Capability

```bash
# Prerequisites: AWS Identity Center must be configured

# Get Identity Center info
export IDC_INSTANCE_ARN=$(aws sso-admin list-instances --query 'Instances[0].InstanceArn' --output text)
export IDC_STORE_ID=$(aws sso-admin list-instances --query 'Instances[0].IdentityStoreId' --output text)
export IDC_USER_ID=$(aws identitystore list-users --identity-store-id $IDC_STORE_ID --query 'Users[?UserName==`your-username`].UserId' --output text)

# Create capability
aws eks create-capability \
  --cluster-name your-cluster \
  --capability-name your-argocd \
  --type ARGOCD \
  --role-arn arn:aws:iam::ACCOUNT:role/your-argocd-capability-role \
  --configuration '{
    "argoCd": {
      "awsIdc": {
        "idcInstanceArn": "'$IDC_INSTANCE_ARN'",
        "idcRegion": "us-east-1"
      },
      "rbacRoleMappings": [{
        "role": "ADMIN",
        "identities": [{
          "id": "'$IDC_USER_ID'",
          "type": "SSO_USER"
        }]
      }]
    }
  }'
```

### Verify Capability Status

```bash
aws eks describe-capability \
  --cluster-name your-cluster \
  --capability-name your-argocd
```

### Delete Capability

```bash
aws eks delete-capability \
  --cluster-name your-cluster \
  --capability-name your-argocd
```

## References

- [AWS EKS Managed Argo CD Documentation](https://docs.aws.amazon.com/eks/latest/userguide/argocd.html)
- [Create an Argo CD Capability](https://docs.aws.amazon.com/eks/latest/userguide/create-argocd-capability.html)
- [EKS Capability IAM Role](https://docs.aws.amazon.com/eks/latest/userguide/capability-role.html)
- [AWS Identity Center Setup](https://docs.aws.amazon.com/singlesignon/latest/userguide/getting-started.html)
- [ArgoCD Helm Chart](https://github.com/argoproj/argo-helm)
- [ACK Documentation](https://aws-controllers-k8s.github.io/community/)
- [KRO Documentation](https://github.com/awslabs/kro)
