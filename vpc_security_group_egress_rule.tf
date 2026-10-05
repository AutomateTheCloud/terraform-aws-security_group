# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# One outbound rule per entry of egress_rules. The keys come from the input alone,
# so the rules plan even when a source is created in the same run.
resource "aws_vpc_security_group_egress_rule" "this" {
  for_each = var.egress_rules

  region            = var.region
  security_group_id = aws_security_group.this.id
  description       = local.rules.egress[each.key].description
  ip_protocol       = local.rules.egress[each.key].ip_protocol
  from_port         = local.rules.egress[each.key].from_port
  to_port           = local.rules.egress[each.key].to_port

  cidr_ipv4                    = local.rules.egress[each.key].cidr_ipv4
  cidr_ipv6                    = local.rules.egress[each.key].cidr_ipv6
  prefix_list_id               = local.rules.egress[each.key].prefix_list_id
  referenced_security_group_id = local.rules.egress[each.key].security_group_id

  tags = merge(local.tags, { Name = "${local.name}-${each.key}" })
}
