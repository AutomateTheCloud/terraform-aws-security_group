# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Same-run sources: a VPC, a security group and a prefix list created in the same
# configuration as the module, so their IDs are unknown at plan time.
run "same_run_sources_plan" {
  command = plan
  module {
    source = "./tests/fixtures/same_run"
  }
}

run "same_run_sources_apply" {
  command = apply
  module {
    source = "./tests/fixtures/same_run"
  }
  assert {
    condition     = length(module.web.metadata.vpc_security_group_ingress_rule) == 3 && length(module.web.metadata.vpc_security_group_egress_rule) == 1
    error_message = "Expected three ingress rules and one egress rule."
  }
  assert {
    condition     = module.web.metadata.vpc_security_group_ingress_rule["load_balancer"].referenced_security_group_id == aws_security_group.load_balancer.id && module.web.metadata.vpc_security_group_ingress_rule["cluster"].referenced_security_group_id == module.web.metadata.security_group.id
    error_message = "Unexpected group references."
  }
}

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
  mock_resource "aws_vpc" {
    defaults = { id = "vpc-0123456789abcdef0", cidr_block = "10.0.0.0/16" }
  }
  mock_resource "aws_security_group" {
    defaults = { id = "sg-0123456789abcdef0" }
  }
  mock_resource "aws_ec2_managed_prefix_list" {
    defaults = { id = "pl-0123456789abcdef0" }
  }
}
