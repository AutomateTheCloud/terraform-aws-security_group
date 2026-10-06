# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One inbound rule per entry of ingress_rules. The keys come from the input alone,
# so the rules plan even when a source is created in the same run.
resource "aws_vpc_security_group_ingress_rule" "this" {
  for_each = var.ingress_rules

  region            = var.region
  security_group_id = aws_security_group.this.id
  description       = local.rules.ingress[each.key].description
  ip_protocol       = local.rules.ingress[each.key].ip_protocol
  from_port         = local.rules.ingress[each.key].from_port
  to_port           = local.rules.ingress[each.key].to_port

  cidr_ipv4                    = local.rules.ingress[each.key].cidr_ipv4
  cidr_ipv6                    = local.rules.ingress[each.key].cidr_ipv6
  prefix_list_id               = local.rules.ingress[each.key].prefix_list_id
  referenced_security_group_id = local.rules.ingress[each.key].security_group_id

  tags = merge(local.tags, { Name = "${local.name}-${each.key}" })
}
