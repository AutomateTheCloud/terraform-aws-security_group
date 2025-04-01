variable "category" {
  description = "Security Group Category"
  type        = string
  default     = "ec2"
  validation {
    condition     = var.category != ""
    error_message = "Category not Specified."
  }
}

variable "rules" {
  description = "Security Group Rules"
  type = list(object({
    type        = string
    protocol    = string
    from_port   = number
    to_port     = number
    source      = string # CIDR Block or Security Group ID
    description = string
  }))
}

variable "vpc_id" {
  description = "VPC: ID"
  type        = string
  default     = ""
  validation {
    condition     = var.vpc_id != ""
    error_message = "VPC ID not Specified."
  }
}
