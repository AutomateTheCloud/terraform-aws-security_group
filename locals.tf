# Copyright 2025 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

locals {
  # The Name tag of the group, and the start of its name and of each rule's Name tag.
  name = "${local.scope.abbr}-${local.purpose.abbr}-${local.environment.abbr}-${local.aws.region.abbr}-${var.category}"

  # A group description may contain only these characters, so anything else in the
  # details names is dropped rather than failing the create.
  description = substr(replace(
    "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): ${var.category}",
    "/[^A-Za-z0-9 ._:/()#,@\\[\\]+=&;{}!$*-]/", ""
  ), 0, 255)

  # The rules as the rule resources take them. Ports are set only for the protocols
  # that have them; the ICMP type and code default to -1, every type and code.
  rules = {
    for direction, rules in { egress = var.egress_rules, ingress = var.ingress_rules } : direction => {
      for key, r in rules : key => {
        ip_protocol = r.ip_protocol
        from_port = (
          contains(["tcp", "udp"], r.ip_protocol) ? r.from_port :
          contains(["icmp", "icmpv6"], r.ip_protocol) ? (r.from_port != null ? r.from_port : -1) : null
        )
        to_port = (
          contains(["tcp", "udp"], r.ip_protocol) ? (r.to_port != null ? r.to_port : r.from_port) :
          contains(["icmp", "icmpv6"], r.ip_protocol) ? (r.to_port != null ? r.to_port : -1) : null
        )
        description       = coalesce(r.description, key)
        cidr_ipv4         = r.cidr_ipv4
        cidr_ipv6         = r.cidr_ipv6
        prefix_list_id    = r.prefix_list_id
        security_group_id = r.self ? aws_security_group.this.id : r.security_group_id
      }
    }
  }
}
