# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# Offline tests: every provider is mocked, so no AWS account is used.
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

run "defaults_are_closed" {
  command = apply

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 0 && length(aws_vpc_security_group_egress_rule.this) == 0
    error_message = "No traffic may be allowed by default, in either direction."
  }
  assert {
    condition     = aws_security_group.this.name == "test-web_app-test-use1-ec2" && aws_security_group.this.vpc_id == "vpc-0123456789abcdef0" && aws_security_group.this.revoke_rules_on_delete
    error_message = "Unexpected security group."
  }
  assert {
    condition     = aws_security_group.this.description == "Test - Web App [test] (us-east-1): ec2"
    error_message = "Unexpected security group description: ${aws_security_group.this.description}"
  }
  assert {
    condition     = aws_security_group.this.tags == tomap({ Scope = "Test", Purpose = "Web App", Environment = "test", Name = "test-web_app-test-use1-ec2" })
    error_message = "Unexpected tags."
  }
  assert {
    condition     = output.metadata.vpc_security_group_ingress_rule == null && output.metadata.vpc_security_group_egress_rule == null && output.metadata.security_group.id == aws_security_group.this.id && output.metadata.aws.region.abbr == "use1" && output.metadata.aws.account.id == "111111111111"
    error_message = "Unexpected metadata output."
  }
}

run "abbreviation_override" {
  command = plan
  variables {
    details  = { scope = "Test", purpose = "Web App", environment = "Production", environment_abbr = "prd", additional_tags = { CostCenter = "1234" } }
    category = "database"
  }
  assert {
    condition     = output.metadata.details.environment.abbr == "prd" && output.metadata.details.purpose.machine == "webapp" && aws_security_group.this.tags["Name"] == "test-web_app-prd-use1-database" && aws_security_group.this.tags["CostCenter"] == "1234"
    error_message = "Unexpected details handling."
  }
}

run "details_scope_required" {
  command = plan
  variables { details = { scope = " ", purpose = "p", environment = "e" } }
  expect_failures = [var.details]
}

run "details_purpose_required" {
  command = plan
  variables { details = { scope = "s", purpose = "", environment = "e" } }
  expect_failures = [var.details]
}

run "details_environment_required" {
  command = plan
  variables { details = { scope = "s", purpose = "p", environment = "" } }
  expect_failures = [var.details]
}

run "vpc_id_validated" {
  command = plan
  variables { vpc_id = "subnet-0123456789abcdef0" }
  expect_failures = [var.vpc_id]
}

run "category_not_empty" {
  command = plan
  variables { category = "" }
  expect_failures = [var.category]
}

run "category_characters" {
  command = plan
  variables { category = "web servers" }
  expect_failures = [var.category]
}

run "rule_needs_exactly_one_source" {
  command = plan
  variables { ingress_rules = { both = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", security_group_id = "sg-0123456789abcdef0" } } }
  expect_failures = [var.ingress_rules]
}

run "rule_self_and_cidr" {
  command = plan
  variables { ingress_rules = { both = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", self = true } } }
  expect_failures = [var.ingress_rules]
}

run "rule_needs_a_source" {
  command = plan
  variables { egress_rules = { none = { ip_protocol = "tcp", from_port = 443 } } }
  expect_failures = [var.egress_rules]
}

run "rule_self_false_is_no_source" {
  command = plan
  variables { ingress_rules = { none = { ip_protocol = "tcp", from_port = 443, self = false } } }
  expect_failures = [var.ingress_rules]
}

run "protocol_uppercase_rejected" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "TCP", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "protocol_number_for_tcp_rejected" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "6", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "protocol_number_out_of_range" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "256", cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.egress_rules]
}

run "protocol_all_word_rejected" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "all", cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.egress_rules]
}

run "tcp_needs_from_port" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "tcp_port_range_reversed" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 8080, to_port = 80, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "udp_port_too_high" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "udp", from_port = 65536, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.egress_rules]
}

run "tcp_port_negative" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = -1, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "icmp_type_out_of_range" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "icmp", from_port = 256, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "ports_on_all_protocols_rejected" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "-1", from_port = 0, to_port = 65535, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.egress_rules]
}

run "ports_on_other_protocol_rejected" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "50", from_port = 0, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "cidr_ipv4_must_be_ipv4" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "2001:db8::/56" } } }
  expect_failures = [var.ingress_rules]
}

run "cidr_ipv4_must_be_a_range" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.1" } } }
  expect_failures = [var.ingress_rules]
}

run "cidr_ipv6_must_be_ipv6" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv6 = "10.0.0.0/16" } } }
  expect_failures = [var.egress_rules]
}

run "prefix_list_id_validated" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "tcp", from_port = 443, prefix_list_id = "sg-0123456789abcdef0" } } }
  expect_failures = [var.egress_rules]
}

run "security_group_id_validated" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 443, security_group_id = "pl-0123456789abcdef0" } } }
  expect_failures = [var.ingress_rules]
}

run "description_characters" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", description = "Bob's laptop" } } }
  expect_failures = [var.ingress_rules]
}

run "description_length" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16", description = join("", [for i in range(256) : "a"]) } } }
  expect_failures = [var.egress_rules]
}

run "key_used_as_description_is_checked" {
  command = plan
  variables { ingress_rules = { "Bob's laptop" = { ip_protocol = "tcp", from_port = 22, cidr_ipv4 = "10.0.0.5/32" } } }
  expect_failures = [var.ingress_rules]
}

run "cidr_ipv4_must_start_at_first_address" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.5/16" } } }
  expect_failures = [var.ingress_rules]
}

run "cidr_ipv6_must_be_short_form" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv6 = "2600:1f18:1234:5600:0000::/56" } } }
  expect_failures = [var.egress_rules]
}

run "cidr_ipv6_must_start_at_first_address" {
  command = plan
  variables { egress_rules = { r = { ip_protocol = "tcp", from_port = 443, cidr_ipv6 = "2600:1f18:1234:5601::/56" } } }
  expect_failures = [var.egress_rules]
}

run "icmp_every_type_needs_every_code" {
  command = plan
  variables { ingress_rules = { r = { ip_protocol = "icmp", to_port = 5, cidr_ipv4 = "10.0.0.0/16" } } }
  expect_failures = [var.ingress_rules]
}

run "name_must_not_start_with_sg" {
  command = plan
  variables { details = { scope = "SG", purpose = "Web App", environment = "test" } }
  expect_failures = [aws_security_group.this]
}
