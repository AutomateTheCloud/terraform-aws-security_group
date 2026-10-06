# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Test fixture: the VPC, the source security group and the prefix list are created in
# the same run as the module, so their IDs are not known until apply.
terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0"
    }
  }
}

resource "aws_vpc" "this" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "load_balancer" {
  name        = "load-balancer"
  description = "Load balancer in front of the web servers"
  vpc_id      = aws_vpc.this.id
}

resource "aws_ec2_managed_prefix_list" "offices" {
  name           = "offices"
  address_family = "IPv4"
  max_entries    = 1

  entry {
    cidr = "192.168.0.0/24"
  }
}

module "web" {
  source = "../../.."

  details  = { scope = "Test", purpose = "Same Run", environment = "test" }
  category = "web"
  vpc_id   = aws_vpc.this.id

  ingress_rules = {
    load_balancer = { ip_protocol = "tcp", from_port = 443, security_group_id = aws_security_group.load_balancer.id }
    offices       = { ip_protocol = "tcp", from_port = 22, prefix_list_id = aws_ec2_managed_prefix_list.offices.id }
    cluster       = { ip_protocol = "tcp", from_port = 7946, self = true }
  }
  egress_rules = {
    vpc = { ip_protocol = "tcp", from_port = 5432, cidr_ipv4 = aws_vpc.this.cidr_block }
  }
}
