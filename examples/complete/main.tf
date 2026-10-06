# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Three tiers, each with its own security group, that allow only the traffic between
# them: clients reach the load balancer, the load balancer reaches the application,
# and the application reaches the database and Amazon S3.

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
  description = "ID of the VPC to create the security groups in"
  type        = string
}

variable "vpc_cidr" {
  description = "The VPC's IPv4 range, such as 10.0.0.0/16"
  type        = string
}

variable "client_cidr" {
  description = "IPv4 range of the clients allowed to reach the load balancer, such as your network over AWS Site-to-Site VPN"
  type        = string
}

locals {
  details = {
    scope           = "Example"
    purpose         = "Order Service"
    environment     = "Development"
    additional_tags = { CostCenter = "1234" }
  }
}

data "aws_region" "current" {}

# The AWS-managed prefix list of Amazon S3's addresses in the Region.
data "aws_ec2_managed_prefix_list" "s3" {
  name = "com.amazonaws.${data.aws_region.current.region}.s3"
}

module "load_balancer_security_group" {
  source = "../../"

  details  = local.details
  category = "lb"
  vpc_id   = var.vpc_id

  ingress_rules = {
    https = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = var.client_cidr, description = "HTTPS from clients" }
  }
  egress_rules = {
    app = { ip_protocol = "tcp", from_port = 8080, cidr_ipv4 = var.vpc_cidr, description = "Application servers in the VPC" }
  }
}

module "app_security_group" {
  source = "../../"

  details  = local.details
  category = "app"
  vpc_id   = var.vpc_id

  ingress_rules = {
    load_balancer = { ip_protocol = "tcp", from_port = 8080, security_group_id = module.load_balancer_security_group.metadata.security_group.id }
    cluster_tcp   = { ip_protocol = "tcp", from_port = 7946, self = true, description = "Cluster membership, between application servers" }
    cluster_udp   = { ip_protocol = "udp", from_port = 7946, self = true, description = "Cluster membership, between application servers" }
    ping          = { ip_protocol = "icmp", from_port = 8, cidr_ipv4 = var.vpc_cidr, description = "Ping from the VPC" }
  }
  egress_rules = {
    s3 = { ip_protocol = "tcp", from_port = 443, prefix_list_id = data.aws_ec2_managed_prefix_list.s3.id, description = "Amazon S3" }
  }
}

module "database_security_group" {
  source = "../../"

  details  = local.details
  category = "db"
  vpc_id   = var.vpc_id

  ingress_rules = {
    app = { ip_protocol = "tcp", from_port = 5432, security_group_id = module.app_security_group.metadata.security_group.id, description = "PostgreSQL from application servers" }
  }
}

# The application's rule to the database is added here, not in the module call: the
# database group already refers to the application group, and two module calls that
# refer to each other's metadata form a dependency cycle.
resource "aws_vpc_security_group_egress_rule" "app_to_database" {
  security_group_id            = module.app_security_group.metadata.security_group.id
  description                  = "PostgreSQL to the database"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = module.database_security_group.metadata.security_group.id

  tags = merge(module.app_security_group.metadata.details.tags, { Name = "${module.app_security_group.metadata.security_group.tags["Name"]}-database" })
}

output "security_group_ids" {
  description = "The ID of each tier's security group"
  value = {
    load_balancer = module.load_balancer_security_group.metadata.security_group.id
    app           = module.app_security_group.metadata.security_group.id
    database      = module.database_security_group.metadata.security_group.id
  }
}
