# Complete: three tiers

Three security groups, for a load balancer, application servers and a PostgreSQL database, that allow only the traffic between them:

- Clients in `client_cidr` reach the load balancer on HTTPS (TCP port 443).
- The load balancer reaches the application servers on TCP port 8080. Its outbound rule allows the VPC's range; the application group's inbound rule allows only members of the load balancer's group.
- Application servers reach each other on TCP and UDP port 7946 (`self = true`), answer ping (ICMP echo request) from the VPC, reach Amazon S3 on HTTPS through the AWS-managed prefix list for S3 in the Region, and reach the database on TCP port 5432.
- The database accepts PostgreSQL connections from members of the application group only, and starts no connections.

The rule from the application servers to the database is an `aws_vpc_security_group_egress_rule` outside the module calls. The database group already refers to the application group, and two module calls that refer to each other's `metadata` form a dependency cycle.

## Run it

Choose a VPC, its IPv4 range, and the range of the clients allowed to reach the load balancer:

```shell
terraform init
terraform apply -var 'vpc_id=vpc-0123456789abcdef0' -var 'vpc_cidr=10.0.0.0/16' -var 'client_cidr=192.168.0.0/16'
```

The `security_group_ids` output has each tier's group ID. Security groups cost nothing. Remove them with `terraform destroy` and the same `-var` options, after detaching them from anything that uses them.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Required Inputs

The following input variables are required:

#### <a name="input_client_cidr"></a> [client_cidr](#input_client_cidr)

Description: IPv4 range of the clients allowed to reach the load balancer, such as your network over AWS Site-to-Site VPN

Type: `string`

#### <a name="input_vpc_cidr"></a> [vpc_cidr](#input_vpc_cidr)

Description: The VPC's IPv4 range, such as 10.0.0.0/16

Type: `string`

#### <a name="input_vpc_id"></a> [vpc_id](#input_vpc_id)

Description: ID of the VPC to create the security groups in

Type: `string`

### Outputs

The following outputs are exported:

#### <a name="output_security_group_ids"></a> [security_group_ids](#output_security_group_ids)

Description: The ID of each tier's security group
<!-- END_TF_DOCS -->
