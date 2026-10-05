# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# A security group for web servers that accept HTTPS from inside the VPC, and nothing
# else. It has no outbound rules, so the servers can answer requests but start no
# connections of their own.

terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

variable "vpc_id" {
  description = "ID of the VPC to create the security group in"
  type        = string
}

variable "client_cidr" {
  description = "IPv4 range allowed to connect over HTTPS, such as the VPC's own range"
  type        = string
}

module "web_security_group" {
  source = "../../"

  details = {
    scope       = "Example"
    purpose     = "Web Site"
    environment = "Development"
  }

  category = "web"
  vpc_id   = var.vpc_id

  ingress_rules = {
    https = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = var.client_cidr, description = "HTTPS from clients" }
  }
}

output "security_group_id" {
  description = "The ID to put in an instance's vpc_security_group_ids"
  value       = module.web_security_group.metadata.security_group.id
}
