# Task Manager DevOps Platform

**Educational Project**: Demonstrates production-grade DevOps practices using minimal microservices. Focus on infrastructure, automation, and observability.

## Why This Stack?

### Application Layer
- **Python Flask (Task Service)**: Prometheus instrumentation, REST API patterns, pytest integration
- **Node.js Express (User Service)**: Polyglot microservices, independent scaling, npm ecosystem
- **Nginx**: Centralized API gateway for routing and load balancing

### Infrastructure
- **Docker**: Multi-stage builds, security scanning with Trivy
- **Kubernetes**: Resource limits, health probes, horizontal autoscaling
- **Terraform**: Reproducible infrastructure provisioning

### DevOps Tools
- **ArgoCD**: GitOps continuous delivery with automatic sync
- **Kyverno**: Policy enforcement for security and compliance
- **Prometheus**: Time-series metrics collection
- **Grafana**: Monitoring dashboards and visualization
- **Vault**: Secure secrets management
- **GitHub Actions**: Automated CI/CD pipelines

## Architecture

```
External → Nginx Gateway (:30080)
          ├─ /api/tasks → Task Service (Python:5000)
          └─ /api/users → User Service (Node.js:3000)

Monitoring: Services → Prometheus (:30090) → Grafana (:30300)
GitOps: Git Repo → ArgoCD → Kubernetes
Policy: Kyverno → Admission Control → Deployments
Secrets: Vault (:30820)
```

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 20.10+ | Container runtime |
| Minikube | 1.30+ | Local Kubernetes |
| kubectl | 1.28+ | Kubernetes CLI |
| Terraform | 1.0+ | Infrastructure provisioning |

**System**: 4 CPU cores, 8GB RAM, 20GB disk

## Quick Start

```bash
# Start cluster
minikube start --cpus=2 --memory=4096 --driver=docker
minikube addons enable metrics-server

# Provision infrastructure
cd terraform && terraform init && terraform apply -auto-approve && cd ..

# Deploy all services
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/task-service/
kubectl apply -f kubernetes/user-service/
kubectl apply -f kubernetes/nginx/
kubectl apply -f kubernetes/monitoring/
kubectl apply -f kubernetes/vault/

# Wait for ready
kubectl wait --for=condition=ready pod --all -n task-manager --timeout=300s

# Access services
export MINIKUBE_IP=$(minikube ip)
echo "API: http://$MINIKUBE_IP:30080"
echo "Prometheus: http://$MINIKUBE_IP:30090"
echo "Grafana: http://$MINIKUBE_IP:30300 (admin/admin123)"
echo "Vault: http://$MINIKUBE_IP:30820 (token: root)"
```

## API Usage

### Task Service
```bash
# List all tasks
curl http://$(minikube ip):30080/api/tasks

# Create task
curl -X POST http://$(minikube ip):30080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Deploy v1.0","description":"Production release","done":false}'

# Update task
curl -X PUT http://$(minikube ip):30080/api/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"done":true}'

# Delete task
curl -X DELETE http://$(minikube ip):30080/api/tasks/1
```

### User Service
```bash
# List all users
curl http://$(minikube ip):30080/api/users

# Create user
curl -X POST http://$(minikube ip):30080/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice","email":"alice@company.com","role":"DevOps Engineer"}'

# Update user
curl -X PUT http://$(minikube ip):30080/api/users/1 \
  -H "Content-Type: application/json" \
  -d '{"role":"Senior DevOps Engineer"}'
```

## Monitoring

### Prometheus Queries
```promql
# Service availability
up{job=~"task-service|user-service"}

# HTTP request rate
rate(flask_http_request_total[5m])
rate(http_requests_total[5m])

# Resource usage
process_resident_memory_bytes{job=~"task-service|user-service"}
rate(process_cpu_seconds_total[5m])

# Latency (p95)
histogram_quantile(0.95, rate(flask_http_request_duration_seconds_bucket[5m]))
```

### Grafana Dashboard
```bash
# Import pre-configured dashboard
curl -X POST -H "Content-Type: application/json" -u admin:admin123 \
  -d @docs/grafana-dashboard.json \
  http://$(minikube ip):30300/api/dashboards/db
```

Dashboard panels:
- Service health (UP/DOWN status)
- HTTP request rates
- Memory and CPU utilization
- Request duration percentiles

## GitOps (ArgoCD)

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080 (admin/<password>)
```

ArgoCD automatically syncs the `kubernetes/` directory to the cluster. Manual changes are reverted to maintain Git as the source of truth.

## Policy Enforcement (Kyverno)

Active policies (audit mode):
- **require-labels**: Enforces app/version labels
- **disallow-root-user**: Prevents root containers
- **require-resource-limits**: Mandates CPU/memory limits

```bash
# View violations
kubectl get policyreport -A
kubectl describe policyreport -n task-manager
```

## Secrets Management (Vault)

```bash
# Configure access
export VAULT_ADDR="http://$(minikube ip):30820"
export VAULT_TOKEN="root"

# Store secret
curl -X POST -H "X-Vault-Token: $VAULT_TOKEN" \
  -d '{"data":{"username":"admin","password":"secure123"}}' \
  $VAULT_ADDR/v1/secret/data/database/credentials

# Retrieve secret
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/secret/data/database/credentials | jq '.data.data'
```

## CI/CD Pipelines

GitHub Actions workflows (`.github/workflows/`):

**Task Service**:
1. pytest with coverage
2. Trivy security scan
3. Docker build
4. Registry push (optional)

**User Service**:
1. npm test with coverage
2. Trivy security scan
3. Docker build
4. Registry push (optional)

Local testing:
```bash
# Task Service
cd services/task-service && python -m pytest tests/ -v --cov=app

# User Service
cd services/user-service && npm test
```

## Project Structure

```
├── .github/workflows/          # CI/CD pipelines
├── services/
│   ├── task-service/          # Python Flask API + tests
│   └── user-service/          # Node.js Express API + tests
├── kubernetes/
│   ├── task-service/          # K8s manifests
│   ├── user-service/          # K8s manifests
│   ├── nginx/                 # API Gateway
│   ├── monitoring/            # Prometheus + Grafana
│   ├── vault/                 # Secrets management
│   └── kyverno/               # Security policies
├── terraform/                 # IaC provisioning
├── docs/                      # Grafana dashboards
└── docker-compose.yaml        # Local development
```

## Key Learning Outcomes

- Container orchestration with resource management
- Infrastructure as Code with Terraform
- GitOps workflow implementation
- Policy-based security enforcement
- Metrics collection and visualization
- Secrets management patterns
- CI/CD automation
- Microservices with API gateway
- Polyglot service integration

## Notes

This project uses development configurations (in-memory databases, dev-mode Vault, minimal replicas) for educational purposes. Production deployments require persistent storage, multi-node clusters, TLS, authentication, and additional security hardening.

## License

MIT License - Educational purposes
