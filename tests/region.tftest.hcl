# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1", description = "US East (N. Virginia)" }
  }
  mock_data "aws_caller_identity" {
    defaults = { account_id = "111111111111" }
  }
}

variables {
  details = { scope = "Test", purpose = "Web App", environment = "test" }
  vpc_id  = "vpc-0123456789abcdef0"
}

run "provider_region_by_default" {
  command = plan
  assert {
    condition     = output.metadata.aws.region.name == "us-east-1"
    error_message = "Expected the provider's Region."
  }
}

run "region_reaches_every_resource" {
  command = apply
  variables {
    region        = "us-west-2"
    ingress_rules = { vpc = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } }
    egress_rules  = { vpc = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition = alltrue([
      aws_security_group.this.region == "us-west-2",
      aws_vpc_security_group_ingress_rule.this["vpc"].region == "us-west-2",
      aws_vpc_security_group_egress_rule.this["vpc"].region == "us-west-2",
      output.metadata.aws.region.name == "us-west-2",
    ])
    error_message = "region was not passed through to every resource."
  }
}

# Any Region plans, including ones added after this module was written.
run "region_not_in_old_tables" {
  command = plan
  variables { region = "ca-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "caw1" && aws_security_group.this.tags["Name"] == "test-web_app-test-caw1-ec2"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_southeast" {
  command = plan
  variables { region = "ap-southeast-7" }
  assert {
    condition     = output.metadata.aws.region.abbr == "apse7"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_mexico" {
  command = plan
  variables { region = "mx-central-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "mxc1"
    error_message = "Unexpected abbreviation."
  }
}

run "region_abbreviation_override" {
  command = plan
  variables { region = "us-gov-west-1" }
  assert {
    condition     = output.metadata.aws.region.abbr == "ugw1"
    error_message = "Unexpected abbreviation."
  }
}
