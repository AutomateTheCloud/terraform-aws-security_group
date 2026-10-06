# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Regression tests for the bugs fixed when the module was rewritten as 1.0.0.
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

# Region abbreviations came from a fixed table, and the plan failed in any Region
# missing from it.
run "region_missing_from_old_table" {
  command = plan
  variables { region = "ap-southeast-5" }
  assert {
    condition     = aws_security_group.this.name == "test-web_app-test-apse5-ec2"
    error_message = "A Region missing from the old table must plan."
  }
}

# A source that was not an IPv4 range was taken as a security group ID, so an IPv6
# range was sent to AWS as source_security_group_id.
run "ipv6_range_is_a_range" {
  command = plan
  variables { ingress_rules = { v6 = { ip_protocol = "tcp", from_port = 443, cidr_ipv6 = "2600:1f18:1234:5600::/56" } } }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["v6"].cidr_ipv6 == "2600:1f18:1234:5600::/56" && aws_vpc_security_group_ingress_rule.this["v6"].referenced_security_group_id == null
    error_message = "An IPv6 range must be sent as cidr_ipv6."
  }
}

# Rules were keyed by type, protocol, ports and source, so two rules that differed
# only in description failed the plan with "Duplicate object key". AWS refuses such
# duplicates anyway (InvalidPermission.Duplicate), so they are now rejected with a
# clear message, in each direction.
run "duplicate_rules_rejected" {
  command = plan
  variables {
    ingress_rules = {
      team_a = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", description = "Team A" }
      team_b = { ip_protocol = "tcp", from_port = 443, to_port = 443, cidr_ipv4 = "10.0.0.0/16", description = "Team B" }
    }
  }
  expect_failures = [var.ingress_rules]
}

run "duplicate_icmp_rules_rejected" {
  command = plan
  variables {
    egress_rules = {
      a = { ip_protocol = "icmp", cidr_ipv4 = "10.0.0.0/16" }
      b = { ip_protocol = "icmp", from_port = -1, to_port = -1, cidr_ipv4 = "10.0.0.0/16" }
    }
  }
  expect_failures = [var.egress_rules]
}

# The same ports and source in both directions, or with different ports, are not duplicates.
run "similar_rules_allowed" {
  command = plan
  variables {
    ingress_rules = {
      https = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" }
      http  = { ip_protocol = "tcp", from_port = 80, cidr_ipv4 = "10.0.0.0/16" }
      udp   = { ip_protocol = "udp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" }
    }
    egress_rules = { https = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 3 && length(aws_vpc_security_group_egress_rule.this) == 1
    error_message = "All four rules must plan."
  }
}

# The group description was built from the details names as they were, and AWS refuses
# any character outside its set, such as an apostrophe or an accented letter.
run "description_safe_for_aws" {
  command = plan
  variables { details = { scope = "O'Brien Café", purpose = "Web App", environment = "test" } }
  assert {
    condition     = can(regex("^[A-Za-z0-9 ._:/()#,@\\[\\]+=&;{}!$*-]{1,255}$", aws_security_group.this.description))
    error_message = "Unexpected description: ${aws_security_group.this.description}"
  }
}

# An empty abbreviation override was used as is, so the name started with "-".
run "empty_abbreviation_override_ignored" {
  command = plan
  variables { details = { scope = "Test", scope_abbr = "", purpose = "Web App", environment = "test" } }
  assert {
    condition     = aws_security_group.this.name == "test-web_app-test-use1-ec2"
    error_message = "An empty override must fall back to the generated abbreviation."
  }
}
