variable "region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "lab_role" {
  description = "IAM role ARN for Lambda function"
  type        = string
}
