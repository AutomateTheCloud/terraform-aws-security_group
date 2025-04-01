resource "aws_security_group" "this" {
  name                   = "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-${var.category}"
  description            = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): ${var.category}"
  vpc_id                 = data.aws_vpc.this.id
  revoke_rules_on_delete = true
  tags = merge(
    local.tags,
    tomap({
      "Name" = "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-${var.category}"
    })
  )
  provider = aws.this
}
