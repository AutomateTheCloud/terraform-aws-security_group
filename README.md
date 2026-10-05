# Terraform module for Amazon VPC security groups

Creates a security group in a VPC, and one rule for each entry in its inbound and outbound rule lists. A security group is a stateful firewall for the network interfaces it is attached to, such as those of EC2 instances, load balancers and databases: it allows only the traffic its rules list, and replies to allowed traffic.

A group created with only the required inputs allows nothing, in either direction, until you add rules.

## What it configures

| Setting | Default | Input |
|---|---|---|
| VPC | Required | `vpc_id` |
| Inbound rules | None: nothing can connect | `ingress_rules` |
| Outbound rules | None: members can start no connections, not even to the internet | `egress_rules` |
| Name | `<scope>-<purpose>-<environment>-<region>-<category>`, the same as the `Name` tag | `details`, `category` (defaults to `ec2`) |
| Rules on delete | Removed before the group is deleted, so groups that refer to each other can be deleted | |

## Usage

```hcl
module "web_security_group" {
  source  = "AutomateTheCloud/security_group/aws"
  version = "~> 1.0"

  details = {
    scope       = "Automate the Cloud"
    purpose     = "Web Site"
    environment = "Production"
  }

  category = "web"
  vpc_id   = "vpc-0123456789abcdef0"

  ingress_rules = {
    https = { ip_protocol = "tcp", from_port = 443, security_group_id = "sg-0123456789abcdef0", description = "HTTPS from the load balancer" }
  }
  egress_rules = {
    database = { ip_protocol = "tcp", from_port = 5432, cidr_ipv4 = "10.0.20.0/24", description = "PostgreSQL in the database subnets" }
  }
}

resource "aws_instance" "web" {
  # ...
  vpc_security_group_ids = [module.web_security_group.metadata.security_group.id]
}
```

`details` and `vpc_id` are the only required inputs. `details` sets the `Scope`, `Purpose` and `Environment` tags on every resource.

Each rule allows one protocol and port range from, or to, exactly one of: an IPv4 range (`cidr_ipv4`), an IPv6 range (`cidr_ipv6`), a managed prefix list (`prefix_list_id`), another security group (`security_group_id`), or the group itself (`self = true`). The keys, such as `https`, are names you choose. The descriptions of `ingress_rules` and `egress_rules` below list every attribute.

The module uses your default `aws` provider and creates everything in that provider's Region. To create the group somewhere else without configuring another provider, set `region`:

```hcl
module "web_security_group_us_west_2" {
  source  = "AutomateTheCloud/security_group/aws"
  version = "~> 1.0"

  region   = "us-west-2"
  details  = { scope = "Automate the Cloud", purpose = "Web Site", environment = "Production" }
  category = "web"
  vpc_id   = "vpc-0abcdef0123456789"
}
```

The VPC must be in that Region too.

To use a provider configured for another account, pass it explicitly with `providers = { aws = aws.other_account }`.

## The `details` input

Most modules ask only for what the resource itself needs. This one also requires `details`: three names that say what the security group belongs to, what it is for, and which environment it is in. Every Automate the Cloud module takes the same input, and requiring it is deliberate.

```hcl
details = {
  scope       = "Automate the Cloud" # what it belongs to: an organization, team or project
  purpose     = "Web Site"           # what it is for
  environment = "Production"         # which environment
}
```

**Every resource can be traced.** The three names become the `Scope`, `Purpose` and `Environment` tags on every resource the module creates. Months later, anyone looking at a security group in the AWS console, or at a line on the bill, can see who it belongs to and why it exists. With cost allocation tags turned on in AWS Billing, the same tags split your bill by project and environment. Because the input is required and checked, no resource can be created without them.

**One definition for a whole stack.** Write `details` once and pass the same value to every module, so the security group, the instances that use it, their VPC and everything else are tagged alike. Tags you want everywhere, such as a cost center or the Terraform workspace, go in `additional_tags`:

```hcl
locals {
  details = {
    scope           = "Automate the Cloud"
    purpose         = "Web Site"
    environment     = "Production"
    additional_tags = { CostCenter = "1234", IaC = "true" }
  }
}

module "web_security_group" {
  source  = "AutomateTheCloud/security_group/aws"
  version = "~> 1.0"

  details = local.details
  vpc_id  = "vpc-0123456789abcdef0"
}
```

**Consistent names.** The module turns each name into two short forms other resources can be named with: `abbr`, lowercase with words joined by underscores (`Web Site` becomes `web_site`), and `machine`, lowercase letters and numbers only (`website`), for resources that allow no underscores. It also works out a short form of the Region, such as `use1` for `us-east-1`. Every module derives these the same way, so names stay consistent across a stack. To choose your own short forms, set `scope_abbr`, `purpose_abbr` or `environment_abbr`, for example `environment_abbr = "prd"`.

**One output to reach everything.** All of it comes back in the `metadata` output, along with everything the module created, so a configuration needs only one reference: `module.web_security_group.metadata.security_group.id` for an instance's `vpc_security_group_ids`, or `module.web_security_group.metadata.aws.region.abbr` for the Region's short form.

## Examples

Each example is a complete configuration you can run with `terraform init` and `terraform apply`, given a VPC.

- [Basic](https://github.com/AutomateTheCloud/terraform-aws-security_group/tree/main/examples/basic): a group for web servers that accept HTTPS from one range.
- [Complete](https://github.com/AutomateTheCloud/terraform-aws-security_group/tree/main/examples/complete): three groups for a load balancer, application servers and a database, which allow only the traffic between them, with a rule to Amazon S3 through its prefix list and rules between members of one group.

## Things to know

### No outbound traffic by default

A security group created in the AWS Management Console, or with the AWS CLI, comes with a rule that allows all outbound traffic. The AWS provider removes that rule when it creates the group, so a group from this module allows no outbound traffic until `egress_rules` lists some. Instances that use it cannot reach package repositories, AWS APIs or the internet. To allow all outbound traffic, as the console does:

```hcl
egress_rules = {
  all_ipv4 = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }
  all_ipv6 = { ip_protocol = "-1", cidr_ipv6 = "::/0" }
}
```

Narrower rules are safer: an AWS-managed prefix list, such as the one for Amazon S3 in the [complete example](https://github.com/AutomateTheCloud/terraform-aws-security_group/tree/main/examples/complete), or the ranges of the services you use.

Security groups are stateful: replies to an allowed connection are allowed in the other direction without a rule.

### Rules AWS refuses or rewrites

AWS refuses two rules in the same direction with the same protocol, ports and source, even with different descriptions; the module refuses them at plan time. It also refuses, at plan time:

- A range that does not start at its first address, such as `10.0.0.5/16`. The AWS provider refuses these too.
- An IPv6 range not in short lowercase form, such as `2600:1f18:1234:5600:0000::/56`. AWS saves it as `2600:1f18:1234:5600::/56`, and every later plan would show the rule changing.
- The protocol numbers 6, 17, 1 and 58, and protocol names in capitals: use `tcp`, `udp`, `icmp` and `icmpv6`. The module's port checks rely on the names.

Rule and group descriptions may contain only letters, numbers, spaces and `._-:/()#,@[]+=&;{}!`. The group's description is built from `details`, and any other character, such as an apostrophe or an accented letter, is left out of it.

### Changing rules

Adding or removing an entry adds or removes only that rule. Changing an entry's protocol, ports, description, or the value of its source updates the rule in place. Changing which kind of source it uses, such as from `cidr_ipv4` to `security_group_id`, replaces the rule: it is removed, then created again.

To add a rule the module does not make, attach it to the group yourself with `aws_vpc_security_group_ingress_rule` or `aws_vpc_security_group_egress_rule` and `security_group_id = module.<name>.metadata.security_group.id`. Do not also manage the group's rules with `aws_security_group_rule`, or with inline `ingress` and `egress` blocks: the [AWS provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) warns that mixing them causes conflicts and can overwrite rules.

### Groups that refer to each other

The `metadata` output includes each group's rules, so two module calls whose rules refer to each other's groups form a dependency cycle, and Terraform refuses to plan. Make one direction's rule with `aws_vpc_security_group_ingress_rule` or `aws_vpc_security_group_egress_rule` outside the module calls, as the [complete example](https://github.com/AutomateTheCloud/terraform-aws-security_group/tree/main/examples/complete) does for the rule from the application servers to the database.

### Settings that replace the group

Changing `vpc_id`, `region`, `category` or `details` replaces the group and every rule: `details` and `category` make up the group's name and description, which AWS cannot change. The old group is deleted first, because the new one has the same name, and then the new one is created with the rules.

A group still attached to a network interface cannot be deleted, so detach it from everything that uses it before such a change, or the change waits. If something still uses the group, `terraform apply` keeps retrying the delete and finishes as soon as the group is detached; it fails if that takes longer than the provider's delete timeout, 15 minutes by default according to the [provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group#timeouts).

### Group names

The group is named `<scope>-<purpose>-<environment>-<region>-<category>`, from the abbreviated forms of `details`. AWS refuses two groups with the same name in one VPC, so give each group with the same `details` in a VPC its own `category`.

### Quotas

AWS allows 60 inbound and 60 outbound rules per group by default, and a prefix list counts as many rules as its maximum number of entries. See [security group quotas](https://docs.aws.amazon.com/vpc/latest/userguide/amazon-vpc-limits.html#vpc-limits-security-groups) to check or raise them.

## Contributing

Contributions are welcome, after review. Read [CONTRIBUTING.md](https://github.com/AutomateTheCloud/terraform-aws-security_group/blob/main/CONTRIBUTING.md) before opening a pull request, and report security problems as described in [SECURITY.md](https://github.com/AutomateTheCloud/terraform-aws-security_group/blob/main/SECURITY.md).

## Testing

The tests in `tests/` run offline against mocked AWS providers, so they need no AWS account:

```shell
terraform init
terraform test
```

## Reference

The sections below are generated from the code by [terraform-docs](https://terraform-docs.io). To update them, run `terraform-docs .`.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (>= 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_details"></a> [details](#input_details)

Description: Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-security_group#the-details-input) explains why it is required.

- `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
- `purpose` - (Required) What the resource is for: `Web Site`.
- `environment` - (Required) The environment: `Production`.
- `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
- `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.

Type:

```hcl
object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
```

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: The ID of the VPC to create the group in, such as `vpc-0123456789abcdef0`. Changing it replaces the group and its rules.

Type: `string`

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_category"></a> [category](#input_category)

Description: What the group is for, such as `web` or `database`. It ends the group's name and `Name` tag, `<scope>-<purpose>-<environment>-<region>-<category>` with the abbreviated forms from `details`, so that several groups with the same `details` can be told apart. Letters, numbers, `.`, `_` and `-`. Defaults to `ec2`.

Changing `category` or `details` renames the group, which replaces it and every rule: AWS cannot rename a security group.

Type: `string`

Default: `"ec2"`

#### <a name="input_egress_rules"></a> [egress_rules](#input_egress_rules)

Description: The outbound rules: what members of the group may connect to. Defaults to `{}`, so members can start no connections at all: unlike a group made in the AWS Management Console, the group has no rule that allows all outbound traffic. Replies to allowed inbound connections need no rule. To allow all outbound traffic, as the console does, add `all_ipv4 = { ip_protocol = "-1", cidr_ipv4 = "0.0.0.0/0" }` and `all_ipv6 = { ip_protocol = "-1", cidr_ipv6 = "::/0" }`.

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

Type:

```hcl
map(object({
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
```

Default: `{}`

#### <a name="input_ingress_rules"></a> [ingress_rules](#input_ingress_rules)

Description: The inbound rules: who may connect to members of the group. Defaults to `{}`, so nothing may connect.

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

Type:

```hcl
map(object({
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
```

Default: `{}`

#### <a name="input_region"></a> [region](#input_region)

Description: The AWS Region to create the group and its rules in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module. The VPC must be in that Region. Changing it replaces the group.

Type: `string`

Default: `null`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created, in one object, so that other configurations need only one reference:

- `details` - The scope, purpose and environment, each with its `name`, `abbr` (lowercase, words joined by underscores) and `machine` (lowercase letters and numbers only) forms, and the `tags` applied to every resource.
- `aws` - The `account.id`, and the `region` `name`, `abbr` (such as `use1` for `us-east-1`) and `description`.
- `security_group` - The group, with its `id` (use it in `vpc_security_group_ids` and `security_groups` arguments), `arn`, `name`, `name_prefix`, `description`, `vpc_id`, `owner_id`, `revoke_rules_on_delete`, `region`, `tags` and `tags_all`. Its rules are in the two entries below.
- `vpc_security_group_egress_rule` - The outbound rules, keyed as in `egress_rules`, each with its `id` and `security_group_rule_id` (the same `sgr-` ID), `arn`, `ip_protocol`, `from_port`, `to_port`, `cidr_ipv4`, `cidr_ipv6`, `prefix_list_id`, `referenced_security_group_id`, `description`, `security_group_id`, `region`, `tags` and `tags_all`; or `null` when there are none.
- `vpc_security_group_ingress_rule` - The inbound rules, keyed as in `ingress_rules`, with the same attributes; or `null` when there are none.
<!-- END_TF_DOCS -->

## License

This module is licensed under the [Apache License 2.0](https://github.com/AutomateTheCloud/terraform-aws-security_group/blob/main/LICENSE). See [NOTICE](https://github.com/AutomateTheCloud/terraform-aws-security_group/blob/main/NOTICE) for the copyright notice.

The Automate the Cloud name and logo are not covered by this license.

---

Maintained by [Automate the Cloud](https://automatethe.cloud), a Kentucky 501(c)(3) that teaches cloud infrastructure and helps nonprofits run theirs.
