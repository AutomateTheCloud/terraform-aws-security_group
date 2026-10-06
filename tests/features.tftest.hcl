# Copyright 2026 Automate the Cloud Inc.
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

# Characters AWS does not accept in a group description are dropped.
run "description_drops_unsupported_characters" {
  command = plan
  variables { details = { scope = "O'Brien Café", purpose = "Web App", environment = "test" } }
  assert {
    condition     = aws_security_group.this.description == "OBrien Caf - Web App [test] (us-east-1): ec2" && aws_security_group.this.tags["Scope"] == "O'Brien Café"
    error_message = "Unexpected description: ${aws_security_group.this.description}"
  }
}

run "every_source_type" {
  command = plan
  variables {
    ingress_rules = {
      vpc      = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", description = "Clients in the VPC" }
      vpc_ipv6 = { ip_protocol = "tcp", from_port = 443, cidr_ipv6 = "2600:1f18:1234:5600::/56" }
      offices  = { ip_protocol = "tcp", from_port = 443, prefix_list_id = "pl-0123456789abcdef0" }
      lb       = { ip_protocol = "tcp", from_port = 443, security_group_id = "sg-0123456789abcdef0" }
      peered   = { ip_protocol = "tcp", from_port = 443, security_group_id = "222222222222/sg-0fedcba9876543210" }
    }
  }
  assert {
    condition = alltrue([
      aws_vpc_security_group_ingress_rule.this["vpc"].cidr_ipv4 == "10.0.0.0/16",
      aws_vpc_security_group_ingress_rule.this["vpc"].cidr_ipv6 == null,
      aws_vpc_security_group_ingress_rule.this["vpc"].description == "Clients in the VPC",
      aws_vpc_security_group_ingress_rule.this["vpc_ipv6"].cidr_ipv6 == "2600:1f18:1234:5600::/56",
      aws_vpc_security_group_ingress_rule.this["vpc_ipv6"].description == "vpc_ipv6",
      aws_vpc_security_group_ingress_rule.this["offices"].prefix_list_id == "pl-0123456789abcdef0",
      aws_vpc_security_group_ingress_rule.this["lb"].referenced_security_group_id == "sg-0123456789abcdef0",
      aws_vpc_security_group_ingress_rule.this["peered"].referenced_security_group_id == "222222222222/sg-0fedcba9876543210",
    ])
    error_message = "Each source must reach its own attribute."
  }
  assert {
    condition     = alltrue([for r in values(aws_vpc_security_group_ingress_rule.this) : r.ip_protocol == "tcp" && r.from_port == 443 && r.to_port == 443])
    error_message = "to_port must default to from_port."
  }
  assert {
    condition     = length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "Ingress rules must not create egress rules."
  }
}

run "ports_per_protocol" {
  command = plan
  variables {
    ingress_rules = {
      range    = { ip_protocol = "tcp", from_port = 8000, to_port = 8099, cidr_ipv4 = "10.0.0.0/16" }
      dns      = { ip_protocol = "udp", from_port = 53, cidr_ipv4 = "10.0.0.0/16" }
      ping     = { ip_protocol = "icmp", from_port = 8, cidr_ipv4 = "10.0.0.0/16" }
      icmp_all = { ip_protocol = "icmp", cidr_ipv4 = "10.0.0.0/16" }
      ndp      = { ip_protocol = "icmpv6", from_port = 135, to_port = 0, cidr_ipv6 = "2600:1f18:1234:5600::/56" }
      ipsec    = { ip_protocol = "50", cidr_ipv4 = "10.0.0.0/16" }
      all      = { ip_protocol = "-1", cidr_ipv4 = "10.0.0.0/16" }
    }
  }
  assert {
    condition = toset([for k, r in aws_vpc_security_group_ingress_rule.this : "${k}|${r.ip_protocol}|${coalesce(r.from_port, "none")}|${coalesce(r.to_port, "none")}"]) == toset([
      "range|tcp|8000|8099",
      "dns|udp|53|53",
      "ping|icmp|8|-1",
      "icmp_all|icmp|-1|-1",
      "ndp|icmpv6|135|0",
      "ipsec|50|none|none",
      "all|-1|none|none",
    ])
    error_message = "Unexpected ports."
  }
}

run "egress_rules" {
  command = plan
  variables {
    egress_rules = {
      https    = { ip_protocol = "tcp", from_port = 443, prefix_list_id = "pl-0123456789abcdef0", description = "Amazon S3" }
      all_ipv4 = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
      all_ipv6 = { ip_protocol = "-1", cidr_ipv6 = "::/0" }
    }
  }
  assert {
    condition     = toset(keys(aws_vpc_security_group_egress_rule.this)) == toset(["https", "all_ipv4", "all_ipv6"]) && length(aws_vpc_security_group_ingress_rule.this) == 0
    error_message = "Egress rules must create egress rules only."
  }
  assert {
    condition     = aws_vpc_security_group_egress_rule.this["https"].prefix_list_id == "pl-0123456789abcdef0" && aws_vpc_security_group_egress_rule.this["https"].description == "Amazon S3" && aws_vpc_security_group_egress_rule.this["all_ipv6"].cidr_ipv6 == "::/0"
    error_message = "Unexpected egress rules."
  }
}

run "self_refers_to_the_group" {
  command = apply
  variables {
    ingress_rules = { cluster = { ip_protocol = "tcp", from_port = 7946, self = true } }
    egress_rules  = { cluster = { ip_protocol = "tcp", from_port = 7946, self = true } }
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["cluster"].referenced_security_group_id == aws_security_group.this.id && aws_vpc_security_group_egress_rule.this["cluster"].referenced_security_group_id == aws_security_group.this.id
    error_message = "self must refer to the module's group."
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["cluster"].security_group_id == aws_security_group.this.id && aws_vpc_security_group_ingress_rule.this["cluster"].tags["Name"] == "test-web_app-test-use1-ec2-cluster"
    error_message = "Rules must be attached to the module's group and tagged."
  }
  assert {
    condition     = output.metadata.vpc_security_group_ingress_rule["cluster"].referenced_security_group_id == aws_security_group.this.id && output.metadata.vpc_security_group_egress_rule["cluster"].from_port == 7946
    error_message = "Unexpected metadata output."
  }
}

# The same key in ingress_rules and egress_rules names two different rules.
run "same_key_in_both_directions" {
  command = plan
  variables {
    ingress_rules = { app = { ip_protocol = "tcp", from_port = 8080, cidr_ipv4 = "10.0.0.0/16" } }
    egress_rules  = { app = { ip_protocol = "tcp", from_port = 5432, cidr_ipv4 = "10.0.0.0/16" } }
  }
  assert {
    condition     = aws_vpc_security_group_ingress_rule.this["app"].from_port == 8080 && aws_vpc_security_group_egress_rule.this["app"].from_port == 5432
    error_message = "Each direction must keep its own rule."
  }
}

# After the group exists, a change to details or category renames the group, as the
# module always has: the name, description and tags all follow.
run "details_change_renames_the_group" {
  command = plan
  variables {
    details  = { scope = "Test", purpose = "Renamed", environment = "test" }
    category = "app"
  }
  assert {
    condition     = aws_security_group.this.name == "test-renamed-test-use1-app" && aws_security_group.this.description == "Test - Renamed [test] (us-east-1): app"
    error_message = "The name and description must follow details and category."
  }
  assert {
    condition     = aws_security_group.this.tags["Name"] == "test-renamed-test-use1-app" && aws_security_group.this.tags["Purpose"] == "Renamed"
    error_message = "The tags must follow details and category."
  }
}
