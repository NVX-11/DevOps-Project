terraform {
  required_version = ">= 1.13"
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

resource "null_resource" "minikube_start" {
  provisioner "local-exec" {
    command = <<-EOT
      minikube start \
        --cpus=2 \
        --memory=4096 \
        --disk-size=30g \
        --driver=docker
    EOT
  }

  provisioner "local-exec" {
    when    = destroy
    command = "minikube delete"
  }
}

resource "null_resource" "enable_addons" {
  depends_on = [null_resource.minikube_start]

  provisioner "local-exec" {
    command = <<-EOT
      minikube addons enable metrics-server
      minikube addons enable ingress
    EOT
  }
}

resource "null_resource" "install_kyverno" {
  depends_on = [null_resource.enable_addons]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create -f https://github.com/kyverno/kyverno/releases/latest/download/install.yaml || true
    EOT
  }
}

resource "null_resource" "install_argocd" {
  depends_on = [null_resource.enable_addons]

  provisioner "local-exec" {
    command = <<-EOT
      kubectl create namespace argocd || true
      kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    EOT
  }
}

resource "null_resource" "build_images" {
  depends_on = [null_resource.minikube_start]

  provisioner "local-exec" {
    command = <<-EOT
      eval $(minikube docker-env)
      docker build -t task-service:latest ../services/task-service
      docker build -t user-service:latest ../services/user-service
    EOT
  }
}

output "minikube_ip" {
  value       = "Run: minikube ip"
  description = "Command to get Minikube IP address"
}

output "argocd_password" {
  value       = "Run: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  description = "Command to get ArgoCD admin password"
  sensitive   = true
}

output "access_urls" {
  value = {
    grafana       = "http://$(minikube ip):30300 (admin/admin123)"
    prometheus    = "http://$(minikube ip):30090"
    alertmanager  = "http://$(minikube ip):30093"
    vault         = "http://$(minikube ip):30820 (token: root)"
    api_gateway   = "http://$(minikube ip):30080"
  }
  description = "Service access URLs"
}
