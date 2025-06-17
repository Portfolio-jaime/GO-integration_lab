output "app_service_name" {
  description = "The name of the Go application service."
  value       = kubernetes_service.go_app_service.metadata[0].name
}