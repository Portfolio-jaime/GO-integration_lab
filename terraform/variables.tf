variable "namespace" {
  description = "The Kubernetes namespace for the application."
  type        = string
  default     = "go-app-ns"
}

variable "app_name" {
  description = "The name of the Go application."
  type        = string
  default     = "go-cloud-app"
}

variable "app_image" {
  description = "The Docker image for the Go application."
  type        = string
  default     = "go-app:v1" # Asegúrate de que esta imagen esté construida y cargada en Kind
}

variable "app_replicas" {
  description = "Number of replicas for the Go application deployment."
  type        = number
  default     = 2
}