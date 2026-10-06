# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

# The group has no inline rules. The AWS provider removes the rule that allows all
# outbound traffic, which AWS adds to every new group, so the group allows nothing
# until rules are attached in vpc_security_group_*_rule.
resource "aws_security_group" "this" {
  region                 = var.region
  name                   = local.name
  description            = local.description
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(local.tags, { Name = local.name })

  # The name and description follow details and category. AWS cannot change either,
  # so a change replaces the group and every rule. The old group is deleted first:
  # the new one has the same name, and names are unique within a VPC.
  lifecycle {
    precondition {
      condition     = !startswith(local.name, "sg-")
      error_message = "The group name would start with \"sg-\", which AWS refuses. Set details.scope_abbr to something other than \"sg\"."
    }
  }
}
