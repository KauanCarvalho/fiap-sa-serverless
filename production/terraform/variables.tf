variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "user_pool_name" {
  description = "Nome do User Pool"
  type        = string
  default     = "fiap-sa-user-pool"
}

variable "order_service_url" {
  description = "URL do serviço de pedidos"
  type        = string
}

variable "secret_key" {
  description = "Secret key for JWT signing"
  type        = string
  sensitive   = true
}
