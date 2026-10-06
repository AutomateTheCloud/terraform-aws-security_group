# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "category" {
  description = <<-EOT
    What the group is for, such as `web` or `database`. It ends the group's name and `Name` tag, `<scope>-<purpose>-<environment>-<region>-<category>` with the abbreviated forms from `details`, so that several groups with the same `details` can be told apart. Letters, numbers, `.`, `_` and `-`. Defaults to `ec2`.

    Changing `category` or `details` renames the group, which replaces it and every rule: AWS cannot rename a security group.
  EOT
  type        = string
  default     = "ec2"
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]{1,64}$", var.category))
    error_message = "category must be 1 to 64 characters: letters, numbers, ., _ and -."
  }
}

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-security_group#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "egress_rules" {
  description = <<-EOT
    The outbound rules: what members of the group may connect to. Defaults to `{}`, so members can start no connections at all: unlike a group made in the AWS Management Console, the group has no rule that allows all outbound traffic. Replies to allowed inbound connections need no rule. To allow all outbound traffic, as the console does, add `all_ipv4 = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }` and `all_ipv6 = { ip_protocol = "-1", cidr_ipv6 = "::/0" }`.

    The module creates one `aws_vpc_security_group_egress_rule` per entry, such as `{ https = { ip_protocol = "tcp", from_port = 443, prefix_list_id = "pl-0123456789abcdef0" } }`. The keys are names you choose; they identify each rule and become part of its `Name` tag, so a destination created in the same configuration can be used. AWS refuses two rules with the same protocol, ports and destination, even with different descriptions.

    Each entry takes:

    - `ip_protocol` - (Required) `tcp`, `udp`, `icmp`, `icmpv6`, `-1` for every protocol, or another IP protocol number, such as `50` for ESP. Use the names, not the numbers, for TCP (6), UDP (17), ICMP (1) and ICMPv6 (58).
    - `from_port` - For `tcp` and `udp`, (Required) the first port of the range. For `icmp` and `icmpv6`, (Optional) the ICMP type; defaults to `-1`, every type. Must be left out for every other protocol.
    - `to_port` - For `tcp` and `udp`, (Optional) the last port of the range; defaults to `from_port`. For `icmp` and `icmpv6`, (Optional) the ICMP code; defaults to `-1`, every code. Must be left out for every other protocol.
    - `description` - (Optional) What the rule is for. Defaults to the key. Up to 255 characters: letters, numbers, spaces and `._-:/()#,@[]+=&;{}!$*`.

    and exactly one destination:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2600:1f18:1234:5600::/56`.
    - `prefix_list_id` - A managed prefix list, such as the AWS-managed list for Amazon S3 in the Region.
    - `security_group_id` - Another security group, whose members are allowed, such as `sg-0123456789abcdef0`. For a group in a peered VPC in another account, use `<account ID>/<group ID>`.
    - `self` - `true` to allow members of this group, such as the nodes of a cluster talking to each other.
  EOT
  type = map(object({
    ip_protocol       = string
    from_port         = optional(number)
    to_port           = optional(number)
    description       = optional(string)
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    prefix_list_id    = optional(string)
    security_group_id = optional(string)
    self              = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      length([for v in [r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.security_group_id, r.self ? true : null] : v if v != null]) == 1
    ])
    error_message = "Each egress_rules entry needs exactly one of cidr_ipv4, cidr_ipv6, prefix_list_id, security_group_id or self = true."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      contains(["tcp", "udp", "icmp", "icmpv6", "-1"], r.ip_protocol) || (can(regex("^[0-9]{1,3}$", r.ip_protocol)) && !contains(["1", "6", "17", "58"], r.ip_protocol) && try(tonumber(r.ip_protocol) <= 255, false))
    ])
    error_message = "egress_rules: ip_protocol must be tcp, udp, icmp, icmpv6, -1, or another protocol number from 0 to 255. Use the names for TCP (6), UDP (17), ICMP (1) and ICMPv6 (58)."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      !contains(["tcp", "udp"], r.ip_protocol) || (
        r.from_port != null &&
        try(r.from_port >= 0 && r.from_port <= 65535 && floor(r.from_port) == r.from_port, false) &&
        (r.to_port == null || try(r.to_port >= r.from_port && r.to_port <= 65535 && floor(r.to_port) == r.to_port, false))
      )
    ])
    error_message = "egress_rules: tcp and udp rules need from_port, from 0 to 65535, and to_port, if set, from from_port to 65535."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      !contains(["icmp", "icmpv6"], r.ip_protocol) || alltrue([
        for p in [r.from_port, r.to_port] : p == null || try(p >= -1 && p <= 255 && floor(p) == p, false)
      ])
    ])
    error_message = "egress_rules: for icmp and icmpv6, from_port (the ICMP type) and to_port (the code) must be from -1 to 255."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      !contains(["icmp", "icmpv6"], r.ip_protocol) || (r.from_port != null && r.from_port != -1) || r.to_port == null || r.to_port == -1
    ])
    error_message = "egress_rules: an icmp or icmpv6 rule for every type (from_port -1) must be for every code too (to_port -1 or left out)."
  }

  validation {
    # What AWS compares to find duplicates: protocol, ports and source. An entry that
    # another check rejects gets a unique placeholder instead.
    condition = length(distinct([
      for k, r in var.egress_rules : try(join("|", [
        r.ip_protocol,
        contains(["tcp", "udp"], r.ip_protocol) ? "${r.from_port}-${r.to_port != null ? r.to_port : r.from_port}" :
        contains(["icmp", "icmpv6"], r.ip_protocol) ? "${r.from_port != null ? r.from_port : -1}-${r.to_port != null ? r.to_port : -1}" : "",
        r.self ? "self" : coalesce(r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.security_group_id, "none"),
      ]), "invalid entry ${k}")
    ])) == length(var.egress_rules)
    error_message = "egress_rules: two entries have the same protocol, ports and destination. AWS refuses duplicates, even with different descriptions; combine them."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      contains(["tcp", "udp", "icmp", "icmpv6"], r.ip_protocol) || (r.from_port == null && r.to_port == null)
    ])
    error_message = "egress_rules: from_port and to_port apply only to tcp, udp, icmp and icmpv6. Leave them out for -1 and other protocols."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      r.cidr_ipv4 == null || (can(cidrnetmask(r.cidr_ipv4)) && !strcontains(coalesce(r.cidr_ipv4, "-"), ":") && try(cidrsubnet(r.cidr_ipv4, 0, 0) == r.cidr_ipv4, false))
    ])
    error_message = "egress_rules: cidr_ipv4 must be an IPv4 range starting at its first address, such as 10.0.0.0/16 (not 10.0.0.5/16)."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      r.cidr_ipv6 == null || (can(cidrhost(r.cidr_ipv6, 0)) && strcontains(coalesce(r.cidr_ipv6, "-"), ":") && try(cidrsubnet(r.cidr_ipv6, 0, 0) == r.cidr_ipv6, false))
    ])
    error_message = "egress_rules: cidr_ipv6 must be an IPv6 range in the short lowercase form AWS saves, starting at its first address, such as 2600:1f18:1234:5600::/56."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      r.prefix_list_id == null || can(regex("^pl-[0-9a-f]+$", r.prefix_list_id))
    ])
    error_message = "egress_rules: prefix_list_id must be a prefix list ID, such as pl-0123456789abcdef0."
  }

  validation {
    condition = alltrue([
      for r in values(var.egress_rules) :
      r.security_group_id == null || can(regex("^([0-9]{12}/)?sg-[0-9a-f]+$", r.security_group_id))
    ])
    error_message = "egress_rules: security_group_id must be a security group ID, such as sg-0123456789abcdef0, or <account ID>/<group ID> for a group in a peered VPC."
  }

  validation {
    condition = alltrue([
      for k, r in var.egress_rules :
      can(regex("^[A-Za-z0-9 ._:/()#,@\\[\\]+=&;{}!$*-]{1,255}$", coalesce(r.description, k)))
    ])
    error_message = "egress_rules: each description (the key, when description is not set) must be 1 to 255 characters: letters, numbers, spaces and ._-:/()#,@[]+=&;{}!$*."
  }
}

variable "ingress_rules" {
  description = <<-EOT
    The inbound rules: who may connect to members of the group. Defaults to `{}`, so nothing may connect.

    The module creates one `aws_vpc_security_group_ingress_rule` per entry, such as `{ https = { ip_protocol = "tcp", from_port = 443, cidr_ipv4 = "10.0.0.0/16" } }`. The keys are names you choose; they identify each rule and become part of its `Name` tag, so a source created in the same configuration can be used. AWS refuses two rules with the same protocol, ports and source, even with different descriptions.

    Each entry takes:

    - `ip_protocol` - (Required) `tcp`, `udp`, `icmp`, `icmpv6`, `-1` for every protocol, or another IP protocol number, such as `50` for ESP. Use the names, not the numbers, for TCP (6), UDP (17), ICMP (1) and ICMPv6 (58).
    - `from_port` - For `tcp` and `udp`, (Required) the first port of the range. For `icmp` and `icmpv6`, (Optional) the ICMP type; defaults to `-1`, every type. Must be left out for every other protocol.
    - `to_port` - For `tcp` and `udp`, (Optional) the last port of the range; defaults to `from_port`. For `icmp` and `icmpv6`, (Optional) the ICMP code; defaults to `-1`, every code. Must be left out for every other protocol.
    - `description` - (Optional) What the rule is for. Defaults to the key. Up to 255 characters: letters, numbers, spaces and `._-:/()#,@[]+=&;{}!$*`.

    and exactly one source:

    - `cidr_ipv4` - An IPv4 range, such as `10.0.0.0/16`.
    - `cidr_ipv6` - An IPv6 range, such as `2600:1f18:1234:5600::/56`.
    - `prefix_list_id` - A managed prefix list, such as the AWS-managed list for Amazon S3 in the Region.
    - `security_group_id` - Another security group, whose members are allowed, such as `sg-0123456789abcdef0`. For a group in a peered VPC in another account, use `<account ID>/<group ID>`.
    - `self` - `true` to allow members of this group, such as the nodes of a cluster talking to each other.
  EOT
  type = map(object({
    ip_protocol       = string
    from_port         = optional(number)
    to_port           = optional(number)
    description       = optional(string)
    cidr_ipv4         = optional(string)
    cidr_ipv6         = optional(string)
    prefix_list_id    = optional(string)
    security_group_id = optional(string)
    self              = optional(bool, false)
  }))
  default  = {}
  nullable = false

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      length([for v in [r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.security_group_id, r.self ? true : null] : v if v != null]) == 1
    ])
    error_message = "Each ingress_rules entry needs exactly one of cidr_ipv4, cidr_ipv6, prefix_list_id, security_group_id or self = true."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      contains(["tcp", "udp", "icmp", "icmpv6", "-1"], r.ip_protocol) || (can(regex("^[0-9]{1,3}$", r.ip_protocol)) && !contains(["1", "6", "17", "58"], r.ip_protocol) && try(tonumber(r.ip_protocol) <= 255, false))
    ])
    error_message = "ingress_rules: ip_protocol must be tcp, udp, icmp, icmpv6, -1, or another protocol number from 0 to 255. Use the names for TCP (6), UDP (17), ICMP (1) and ICMPv6 (58)."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      !contains(["tcp", "udp"], r.ip_protocol) || (
        r.from_port != null &&
        try(r.from_port >= 0 && r.from_port <= 65535 && floor(r.from_port) == r.from_port, false) &&
        (r.to_port == null || try(r.to_port >= r.from_port && r.to_port <= 65535 && floor(r.to_port) == r.to_port, false))
      )
    ])
    error_message = "ingress_rules: tcp and udp rules need from_port, from 0 to 65535, and to_port, if set, from from_port to 65535."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      !contains(["icmp", "icmpv6"], r.ip_protocol) || alltrue([
        for p in [r.from_port, r.to_port] : p == null || try(p >= -1 && p <= 255 && floor(p) == p, false)
      ])
    ])
    error_message = "ingress_rules: for icmp and icmpv6, from_port (the ICMP type) and to_port (the code) must be from -1 to 255."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      !contains(["icmp", "icmpv6"], r.ip_protocol) || (r.from_port != null && r.from_port != -1) || r.to_port == null || r.to_port == -1
    ])
    error_message = "ingress_rules: an icmp or icmpv6 rule for every type (from_port -1) must be for every code too (to_port -1 or left out)."
  }

  validation {
    # What AWS compares to find duplicates: protocol, ports and source. An entry that
    # another check rejects gets a unique placeholder instead.
    condition = length(distinct([
      for k, r in var.ingress_rules : try(join("|", [
        r.ip_protocol,
        contains(["tcp", "udp"], r.ip_protocol) ? "${r.from_port}-${r.to_port != null ? r.to_port : r.from_port}" :
        contains(["icmp", "icmpv6"], r.ip_protocol) ? "${r.from_port != null ? r.from_port : -1}-${r.to_port != null ? r.to_port : -1}" : "",
        r.self ? "self" : coalesce(r.cidr_ipv4, r.cidr_ipv6, r.prefix_list_id, r.security_group_id, "none"),
      ]), "invalid entry ${k}")
    ])) == length(var.ingress_rules)
    error_message = "ingress_rules: two entries have the same protocol, ports and source. AWS refuses duplicates, even with different descriptions; combine them."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      contains(["tcp", "udp", "icmp", "icmpv6"], r.ip_protocol) || (r.from_port == null && r.to_port == null)
    ])
    error_message = "ingress_rules: from_port and to_port apply only to tcp, udp, icmp and icmpv6. Leave them out for -1 and other protocols."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      r.cidr_ipv4 == null || (can(cidrnetmask(r.cidr_ipv4)) && !strcontains(coalesce(r.cidr_ipv4, "-"), ":") && try(cidrsubnet(r.cidr_ipv4, 0, 0) == r.cidr_ipv4, false))
    ])
    error_message = "ingress_rules: cidr_ipv4 must be an IPv4 range starting at its first address, such as 10.0.0.0/16 (not 10.0.0.5/16)."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      r.cidr_ipv6 == null || (can(cidrhost(r.cidr_ipv6, 0)) && strcontains(coalesce(r.cidr_ipv6, "-"), ":") && try(cidrsubnet(r.cidr_ipv6, 0, 0) == r.cidr_ipv6, false))
    ])
    error_message = "ingress_rules: cidr_ipv6 must be an IPv6 range in the short lowercase form AWS saves, starting at its first address, such as 2600:1f18:1234:5600::/56."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      r.prefix_list_id == null || can(regex("^pl-[0-9a-f]+$", r.prefix_list_id))
    ])
    error_message = "ingress_rules: prefix_list_id must be a prefix list ID, such as pl-0123456789abcdef0."
  }

  validation {
    condition = alltrue([
      for r in values(var.ingress_rules) :
      r.security_group_id == null || can(regex("^([0-9]{12}/)?sg-[0-9a-f]+$", r.security_group_id))
    ])
    error_message = "ingress_rules: security_group_id must be a security group ID, such as sg-0123456789abcdef0, or <account ID>/<group ID> for a group in a peered VPC."
  }

  validation {
    condition = alltrue([
      for k, r in var.ingress_rules :
      can(regex("^[A-Za-z0-9 ._:/()#,@\\[\\]+=&;{}!$*-]{1,255}$", coalesce(r.description, k)))
    ])
    error_message = "ingress_rules: each description (the key, when description is not set) must be 1 to 255 characters: letters, numbers, spaces and ._-:/()#,@[]+=&;{}!$*."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the group and its rules in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. The VPC must be in that Region. Changing it replaces the group.
  EOT
  type        = string
  default     = null
}

variable "vpc_id" {
  description = <<-EOT
    The ID of the VPC to create the group in, such as `vpc-0123456789abcdef0`. Changing it replaces the group and its rules.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = startswith(var.vpc_id, "vpc-")
    error_message = "vpc_id must be a VPC ID, such as vpc-0123456789abcdef0."
  }
}
