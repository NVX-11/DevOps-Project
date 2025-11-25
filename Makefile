.PHONY: help setup build deploy destroy test clean logs monitor

help:
	@echo "Task Manager DevOps - Available Commands:"
	@echo ""
	@echo "Setup & Infrastructure:"
	@echo "  make setup          - Initialize Minikube cluster with Terraform"
	@echo "  make build          - Build Docker images for all services"
	@echo "  make deploy         - Deploy all services to Kubernetes"
	@echo "  make destroy        - Destroy Minikube cluster"
	@echo ""
	@echo "Development:"
	@echo "  make dev            - Run services locally with Docker Compose"
	@echo "  make test           - Run all tests"
	@echo "  make clean          - Clean up local resources"
	@echo ""
	@echo "Operations:"
	@echo "  make logs           - Tail logs from all services"
	@echo "  make monitor        - Open Grafana dashboard"
	@echo "  make status         - Check status of all pods"
	@echo "  make scale          - Scale services (usage: make scale SERVICE=task-service REPLICAS=3)"
	@echo ""
	@echo "Access:"
	@echo "  make urls           - Show all service URLs"
	@echo "  make test-api       - Test API endpoints"

setup:
	@echo "Starting Minikube cluster..."
	cd terraform && terraform init && terraform apply -auto-approve
	@echo "Cluster ready!"

build:
	@echo "Building Docker images..."
	eval $$(minikube docker-env) && \
	docker build -t task-service:latest services/task-service && \
	docker build -t user-service:latest services/user-service
	@echo "Images built successfully!"

deploy:
	@echo "Deploying to Kubernetes..."
	kubectl apply -f kubernetes/namespace.yaml
	kubectl apply -f kubernetes/task-service/
	kubectl apply -f kubernetes/user-service/
	kubectl apply -f kubernetes/nginx/
	kubectl apply -f kubernetes/monitoring/prometheus/
	kubectl apply -f kubernetes/monitoring/grafana/
	kubectl apply -f kubernetes/monitoring/loki/
	kubectl apply -f kubernetes/monitoring/alertmanager/
	kubectl apply -f kubernetes/vault/
	kubectl apply -f kubernetes/kyverno/
	kubectl apply -f kubernetes/ingress.yaml
	@echo "Deployment complete!"
	@echo "Waiting for pods to be ready..."
	kubectl wait --for=condition=ready pod -l app=task-service -n task-manager --timeout=120s
	kubectl wait --for=condition=ready pod -l app=user-service -n task-manager --timeout=120s

destroy:
	@echo "Destroying infrastructure..."
	cd terraform && terraform destroy -auto-approve

dev:
	@echo "Starting services with Docker Compose..."
	docker-compose up --build

test:
	@echo "Running Task Service tests..."
	cd services/task-service && python -m pytest test_app.py -v
	@echo "Running User Service tests..."
	cd services/user-service && npm test

clean:
	@echo "Cleaning up..."
	docker-compose down -v
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name node_modules -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

logs:
	@echo "Tailing logs from all services..."
	kubectl logs -f -n task-manager -l app=task-service --tail=50 &
	kubectl logs -f -n task-manager -l app=user-service --tail=50 &
	wait

monitor:
	@echo "Opening Grafana..."
	@MINIKUBE_IP=$$(minikube ip) && \
	echo "Grafana: http://$$MINIKUBE_IP:30300" && \
	echo "Username: admin" && \
	echo "Password: admin123" && \
	xdg-open "http://$$MINIKUBE_IP:30300" 2>/dev/null || open "http://$$MINIKUBE_IP:30300" 2>/dev/null || echo "Please open manually"

status:
	@echo "Checking pod status..."
	kubectl get pods -n task-manager
	@echo ""
	@echo "Service endpoints:"
	kubectl get svc -n task-manager

scale:
	@if [ -z "$(SERVICE)" ] || [ -z "$(REPLICAS)" ]; then \
		echo "Usage: make scale SERVICE=task-service REPLICAS=3"; \
	else \
		kubectl scale deployment $(SERVICE) -n task-manager --replicas=$(REPLICAS); \
		echo "Scaled $(SERVICE) to $(REPLICAS) replicas"; \
	fi

urls:
	@echo "Service URLs:"
	@MINIKUBE_IP=$$(minikube ip) && \
	echo "API Gateway:    http://$$MINIKUBE_IP:30080" && \
	echo "Grafana:        http://$$MINIKUBE_IP:30300 (admin/admin123)" && \
	echo "Prometheus:     http://$$MINIKUBE_IP:30090" && \
	echo "AlertManager:   http://$$MINIKUBE_IP:30093" && \
	echo "Vault:          http://$$MINIKUBE_IP:30820 (token: root)"

test-api:
	@echo "Testing API endpoints..."
	@MINIKUBE_IP=$$(minikube ip) && \
	echo "Testing Task Service:" && \
	curl -s http://$$MINIKUBE_IP:30080/api/tasks | jq . && \
	echo "" && \
	echo "Testing User Service:" && \
	curl -s http://$$MINIKUBE_IP:30080/api/users | jq .
