variable "app_name" {
  description = "Cluster name"
  type        = string
}

variable "app_environment" {
  description = "App environment"
  type        = string
}


variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(string)
}

variable "load_balancer_security_group_id" {
  description = "Load balancer security group ID"
  type        = string
}

