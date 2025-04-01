resource "aws_security_group_rule" "this" {
  for_each                 = { for rule in var.rules : join(";", [rule.type, rule.protocol, rule.from_port, rule.to_port, rule.source]) => rule }
  security_group_id        = aws_security_group.this.id
  type                     = each.value["type"]
  protocol                 = each.value["protocol"]
  from_port                = each.value["from_port"]
  to_port                  = each.value["to_port"]
  cidr_blocks              = (can(cidrnetmask(each.value["source"])) ? [each.value["source"]] : null)
  source_security_group_id = (can(cidrnetmask(each.value["source"])) ? null : each.value["source"])
  description              = try(each.value["description"], null)
  provider                 = aws.this
}
