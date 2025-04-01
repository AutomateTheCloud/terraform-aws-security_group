data "aws_vpc" "this" {
  id       = var.vpc_id
  provider = aws.this
}
