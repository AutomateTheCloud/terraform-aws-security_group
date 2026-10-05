# Basic security group

A security group for web servers that accept HTTPS (TCP port 443) from one IPv4 range, and nothing else. It has no outbound rules: the servers can answer requests, because security groups allow replies, but cannot start connections of their own. Add `egress_rules` for anything they need to reach.

## Run it

Choose a VPC, and the range allowed to connect, such as the VPC's own range:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'client_cidr=10.0.0.0/16'
```

The `security_group_id` output is the ID to put in an instance's `vpc_security_group_ids`. A security group costs nothing. Remove it with `terraform destroy` and the same `-var` options, after detaching it from anything that uses it.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_client_cidr"></a> [client_cidr](#input_client_cidr)

Description: IPv4 range allowed to connect over HTTPS, such as the VPC's own range

Type: `string`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the security group in

Type: `string`

### Outputs

The following outputs are exported:

#### <a name="output_security_group_id"></a> [security_group_id](#output_security_group_id)

Description: The ID to put in an instance's vpc_security_group_ids
<!-- END_TF_DOCS -->
