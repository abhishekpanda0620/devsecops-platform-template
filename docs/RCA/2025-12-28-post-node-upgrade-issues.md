# RCA: Node Upgrade Broke Everything

**Date:** 2025-12-28
**Author:** Abhishek Panda
**Duration:** ~2 hours

## What Happened

Upgraded nodes from t3.medium to t3.large. After that, half the pods were dead.

## The Issues

### 1. All PVCs stuck in Pending

Checked with `kubectl get pvc -A` - everything was Pending. Prometheus, Grafana, Loki, Falco Redis - all waiting for storage.

**Why:** No EBS CSI driver installed. We had the old gp2 StorageClass but Helm charts were asking for gp3. Without the CSI driver, gp3 doesn't work.

**Fix:**

- Added EBS CSI driver addon to the EKS terraform module
- Created gp3 StorageClass
- Applied terraform, storage started working

### 2. Falco pods crashing

`kubectl logs` showed:

```
Error: unable to mmap the perf-buffer for cpu '0': Cannot allocate memory
```

**Why:** eBPF driver can't allocate memory on these nodes. Known issue.

**Fix:** Disabled Falco for now. Can switch to kernel module driver later if needed.

### 3. LoadBalancer not working

Service had external IP but curl was timing out. Checked the IP - it was internal (10.0.x.x). Classic ELB was created instead of ALB.

Also found this in events:

```
AccessDenied: elasticloadbalancing:AddTags on resource: .../listener/...
```

**Why:** Two problems:

1. LB Controller IAM policy missing listener permissions
2. Service was creating legacy Classic ELB, not using the LB Controller

**Fix:**

- Added listener ARNs to IAM policy
- Switched from LoadBalancer service type to Ingress with ALB annotations
- Deleted the old Classic ELB

### 4. Smoke test failing in CI/CD

Pipeline kept waiting for ingress URL.

**Why:** Two things:

1. smoke-test.sh was hitting `http://user-service.dev:3000` which doesn't exist from GitHub runners
2. GitHub Actions IAM role wasn't in aws-auth ConfigMap so kubectl couldn't talk to the cluster

**Fix:**

- Updated cd.yml to get actual ingress URL from cluster
- Added GitHub Actions role to aws-auth with system:masters

## What Changed

| File | What |
|------|------|
| modules/eks/main.tf | EBS CSI driver |
| modules/eks-gitops/main.tf | LB Controller IAM fix |
| k8s/base/gp3-storageclass.yaml | New StorageClass |
| k8s/overlays/dev/ingress.yaml | ALB Ingress |
| k8s/overlays/dev/service-patch.yaml | ClusterIP now |
| argocd/apps/falco.yaml.disabled | Turned off Falco |
| .github/workflows/cd.yml | Fixed smoke test |
| aws-auth ConfigMap | GitHub role access |

## Future Improvements

- EBS CSI driver should be in base EKS setup
- Manage aws-auth via terraform, not manual patches
- Use Ingress by default, not LoadBalancer service
