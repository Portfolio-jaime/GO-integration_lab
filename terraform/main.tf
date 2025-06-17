terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config" # Ensure this points to your kubeconfig file
  config_context = "kind-go-cloud-native-lab"
}

resource "kubernetes_namespace" "app_namespace" {
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_deployment" "go_app_deployment" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    labels = {
      app = var.app_name
    }
  }

  spec {
    replicas = var.app_replicas
    selector {
      match_labels = {
        app = var.app_name
      }
    }
    template {
      metadata {
        labels = {
          app = var.app_name
        }
      }
      spec {
        container {
          name  = var.app_name
          image = var.app_image
          port {
            container_port = 8080
          }
          env {
            name  = "APP_NAME"
            value = var.app_name
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "go_app_service" {
  metadata {
    name      = var.app_name
    namespace = kubernetes_namespace.app_namespace.metadata[0].name
    labels = {
      app = var.app_name
    }
  }
  spec {
    selector = {
      app = kubernetes_deployment.go_app_deployment.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 8080
    }
    type = "NodePort" # Usamos NodePort para facilitar el acceso localmente
  }
}