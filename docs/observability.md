# Observability Stack

This document describes the observability stack for the DevSecOps Platform Template.

## Overview

The observability stack provides comprehensive monitoring, logging, and tracing capabilities:

| Component | Purpose | Technology |
|-----------|---------|------------|
| **Metrics** | Application & infrastructure metrics | Prometheus + Grafana |
| **Logging** | Centralized log aggregation | Loki + Promtail |
| **Tracing** | Distributed request tracing | Tempo (optional) |
| **Alerting** | Proactive incident detection | Alertmanager |

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Observability Stack                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                 │
│  │   Grafana   │◄───│ Prometheus  │◄───│ServiceMonitor│                │
│  │ Dashboards  │    │   Server    │    │    (CRD)    │                 │
│  └─────────────┘    └──────┬──────┘    └─────────────┘                 │
│         │                  │                                             │
│         ▼                  ▼                                             │
│  ┌─────────────┐    ┌─────────────┐                                     │
│  │    Loki     │◄───│ Alertmanager│───► Slack/PagerDuty/Email          │
│  │   (Logs)    │    │             │                                     │
│  └──────┬──────┘    └─────────────┘                                     │
│         │                                                                │
│         ▼                                                                │
│  ┌─────────────┐                                                        │
│  │  Promtail   │◄─── Pod Logs                                           │
│  │ (Collector) │                                                        │
│  └─────────────┘                                                        │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

## Installation

### Option 1: ArgoCD (GitOps - Recommended)

Deploy the observability stack via ArgoCD:

```bash
# Deploy the observability ArgoCD application
make observability-argocd

# Or manually
kubectl apply -f infra/argocd/apps/observability.yaml

# Sync the application
argocd app sync observability-stack
```

### Option 2: Helm (Direct Install)

For non-GitOps environments or local development:

```bash
# Add Helm repos and install
make observability-install

# Or step by step:
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus Stack
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace observability \
  --create-namespace \
  --values infra/helm/charts/observability/values.yaml

# Install Loki Stack
helm upgrade --install loki grafana/loki-stack \
  --namespace observability \
  --set loki.persistence.enabled=true \
  --set promtail.enabled=true \
  --set grafana.enabled=false  # Using grafana from prometheus stack
```

## Accessing Dashboards

### Grafana

```bash
# Port-forward Grafana
make observability-portforward
# or
kubectl port-forward -n observability svc/prometheus-grafana 3000:80

# Open in browser
open http://localhost:3000
```

**Default Credentials:**

- Username: `admin`
- Password: `prom-operator` (or check: `kubectl get secret -n observability prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d`)

### Prometheus

```bash
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

### Alertmanager

```bash
kubectl port-forward -n observability svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Open http://localhost:9093
```

## Pre-configured Dashboards

The stack includes the following dashboards:

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Kubernetes Cluster | 7249 | Cluster-wide metrics |
| Node Exporter | 1860 | Node-level metrics |
| User Service | Custom | Application-specific metrics |

### Custom Application Dashboard

The User Service dashboard (`infra/k8s/base/grafana-dashboard.yaml`) provides:

- Request rate by status code
- Request latency (p50, p95)
- Error rate
- Running pod count
- Memory usage per pod
- CPU usage per pod

## Alerting Rules

### Default Alerts

The kube-prometheus-stack includes alerts for:

- Node availability
- Pod health
- Resource utilization
- Kubernetes components

### Custom Application Alerts

Custom alerts are defined in `infra/helm/charts/observability/values.yaml`:

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | Error rate > 5% for 5m | critical |
| HighLatency | p95 latency > 1s for 5m | warning |
| PodCrashLooping | > 3 restarts in 15m | critical |
| HighMemoryUsage | Memory > 90% limit | warning |
| PersistentVolumeAlmostFull | PV > 90% full | warning |

### Configuring Alert Receivers

Edit `values-prod.yaml` to configure alert destinations:

```yaml
alertmanager:
  config:
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
            channel: '#alerts'
            send_resolved: true

      - name: 'pagerduty-critical'
        pagerduty_configs:
          - service_key: 'YOUR_PAGERDUTY_SERVICE_KEY'
            severity: critical
```

## ServiceMonitor

Applications are discovered by Prometheus using ServiceMonitors. The user-service includes:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: user-service
spec:
  selector:
    matchLabels:
      app: user-service
  endpoints:
    - port: http
      path: /health/metrics
      interval: 30s
```

### Exposing Application Metrics

Ensure your application exposes Prometheus metrics:

```javascript
// Node.js example with prom-client
const prometheus = require('prom-client');

// Enable default metrics
prometheus.collectDefaultMetrics();

// Custom metrics
const httpRequestDuration = new prometheus.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5]
});

// Expose /health/metrics endpoint
app.get('/health/metrics', async (req, res) => {
  res.set('Content-Type', prometheus.register.contentType);
  res.end(await prometheus.register.metrics());
});
```

## Environment-specific Configuration

### Development

- Shorter retention (3 days)
- Reduced resources
- No HA
- Ephemeral storage

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --values infra/helm/charts/observability/values-dev.yaml
```

### Production

- 30-day retention
- High availability (replicas: 2)
- Persistent storage
- Alert integrations configured

```bash
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --values infra/helm/charts/observability/values-prod.yaml
```

## Troubleshooting

### Check Status

```bash
# Show all observability pods
make observability-status

# Check Prometheus targets
kubectl port-forward -n observability svc/prometheus-kube-prometheus-prometheus 9090:9090
# Navigate to Status > Targets in Prometheus UI
```

### Common Issues

**Prometheus not scraping targets:**

```bash
# Check ServiceMonitor exists
kubectl get servicemonitors -A

# Check Prometheus config
kubectl get secret -n observability prometheus-kube-prometheus-prometheus -o jsonpath='{.data.prometheus\.yaml\.gz}' | base64 -d | gunzip
```

**Grafana datasource not working:**

```bash
# Verify Prometheus service
kubectl get svc -n observability | grep prometheus

# Test connectivity from Grafana pod
kubectl exec -n observability -it $(kubectl get pod -n observability -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}') -- curl prometheus-kube-prometheus-prometheus:9090/api/v1/status/config
```

### Uninstall

```bash
make observability-uninstall
# or
helm uninstall prometheus -n observability
helm uninstall loki -n observability
kubectl delete namespace observability
```

## Resource Requirements

### Minimum (Development)

| Component | CPU Request | Memory Request |
|-----------|------------|----------------|
| Prometheus | 100m | 256Mi |
| Grafana | 50m | 64Mi |
| Alertmanager | 25m | 32Mi |
| Loki | 100m | 128Mi |
| Promtail (per node) | 25m | 32Mi |

### Recommended (Production)

| Component | CPU Request | Memory Request | Storage |
|-----------|------------|----------------|---------|
| Prometheus | 500m | 2Gi | 100Gi |
| Grafana | 200m | 256Mi | 20Gi |
| Alertmanager | 100m | 128Mi | 10Gi |
| Loki | 200m | 512Mi | 50Gi |
| Promtail (per node) | 100m | 128Mi | - |
