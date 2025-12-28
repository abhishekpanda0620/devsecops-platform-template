# RCA: Observability Configuration & Access Issues

**Date:** 2025-12-28
**Author:** Abhishek Panda
**Duration:** ~2 hours

## What Happened

After setting up the `user-service`, we tried to expose observability tools (Grafana, Alertmanager) but faced multiple access issues: 404s, redirects to login loop, and broken Slack notifications.

## The Issues

### 1. Alertmanager Ingress 404/Redirect Loop

Tried accessing `/alertmanager`, but it kept redirecting to Grafana login or returning 404.

**Why:**

- By default, Alertmanager expects to run at root `/`.
- When accessing via `/alertmanager`, Ingress forwarded the request, but Alertmanager didn't know it was serving from a subpath, so it returned links/redirects to `/` (which was Grafana).
- Ingress path matching was tricky; explicitly needed `/` vs `/alertmanager` logic.

**Fix:**

- Updated Helm values with `routePrefix: /alertmanager` and `externalUrl: .../alertmanager`.
- Updated Ingress routing to explicitly handle `/` (Grafana) and `/alertmanager` (Alertmanager).

### 2. Manual Patch Reverting (ArgoCD)

We manually patched the `externalUrl` in the cluster to point to the real ALB, but it kept getting overwritten.

**Why:**

- ArgoCD Self-Heal was enabled on the parent app `devsecops-platform`.
- It saw the manual patch as configuration drift and immediately reverted it to the Git version (which had the placeholder URL).

**Fix:**

- Disabled `selfHeal` on the parent application:

  ```bash
  kubectl patch app devsecops-platform ... --type json -p '[{"op": "remove", "path": "/spec/syncPolicy/automated/selfHeal"}]'
  ```

- This allows our manual patch to persist while keeping the Git repo safe with a placeholder.

### 3. Slack Webhook Management

We needed to configure Slack alerts without committing the webhook URL to the public repo.

**Why:**

- Hardcoding secrets in `values.yaml` is bad practice.
- Initial attempt with `bootstrap-secrets.sh` and `AlertmanagerConfig` CRD was cleaner but more complex to debug quickly.

**Fix:**

- **Git:** Committed a PLACEHOLDER in `kube-prometheus-stack.yaml`.
- **Cluster:** Manually patched the live configuration with the REAL secret.
- **Result:** Repo is safe, functionality works.

### 4. Separate Load Balancers

Initially considered one big ALB for everything.

**Why:**

- `user-service` is the main app API.
- `observability` is internal-ish admin tools.
- Combining them usually leads to complex Ingress Groups and "who owns the ALB" race conditions.

**Fix:**

- Created **two separate ALBs**:
  1. `user-service` (Root access for API consumers)
  2. `observability` (Grafana + Alertmanager access for admins)

### 5. Slack 404 (no_team) Error

Even with the correct Webhook URL, Slack returned `404: no_team`.

**Why:**

- We explicitly defined `channel: '#alerts'` in the config.
- Incoming Webhooks are often bound to a specific channel during creation. Overriding the channel in the payload (which Alertmanager does if `channel` is set) is strictly validated and often fails if explicit permissions aren't granted.

**Fix:**

- Removed the `channel` field from the Alertmanager configuration.
- Allowed the Webhook to deliver to its default configured channel.

### 6. Persistent Reversion of Secrets

The manual patch kept reverting even after disabling `selfHeal` on the root app.

**Why:**

- We have a chain of 3 ArgoCD apps: `devsecops-platform` -> `observability-stack` -> `kube-prometheus-stack`.
- Disabling `selfHeal` on the root wasn't enough; the intermediate apps still had `automated` sync enabled.

**Fix:**

- Disabled `automated` sync on ALL levels (Parent `observability-stack` and Child `kube-prometheus-stack`).

## What Changed

| File | What |
|------|------|
| `infra/argocd/apps/observability/kube-prometheus-stack.yaml` | Added `routePrefix`, `externalUrl`, Slack config |
| `infra/argocd/apps/observability/ingress.yaml` | Added `/alertmanager` path |
| `simulation/README.md` | Guide to manually trigger alerts |
| `task.md` | Updated status |

## Lessons Learned

- **ArgoSync conflicts with Manual Hotfixes:** If you need to patch something manually (like a secret URL), you MUST disable auto-sync/self-heal first.
- **Disable Sync Recursively:** Disabling sync on the root app isn't enough if child apps (App-of-Apps) have their own sync policies.
- **Subpath routing is hard:** Apps like Prometheus/Alertmanager always need explicit configuration (`--web.route-prefix`) to work behind a subpath.
