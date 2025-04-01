terraform {
  required_version = "~> 1.11.0"
}

##-----------------------------------------------------------------------------
# Providers
provider "aws" {
  alias  = "example"
  region = "us-east-1"
}

##-----------------------------------------------------------------------------
# Module: Security Group
module "security_group" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope               = "Demo"
    purpose             = "Security Group"
    environment         = "prd"
    additional_tags = {
      "Project"         = "Project Name"
      "ProjectID"       = "123456789"
      "Contact"         = "David Singer - david.singer@example.com"
    }
  }

  vpc_id   = "vpc-00000000000000001"
  category = "ec2"
  rules = [
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source      = "192.168.1.0/24"
      description = "Allow All"
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source      = "192.168.2.0/24"
      description = "Allow All"
    },
    {
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source      = "192.168.3.0/24"
      description = "Allow All"
    },
    {
      type        = "egress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      source      = "0.0.0.0/0"
      description = "Allow All"
    }
  ]
}

##-----------------------------------------------------------------------------
# Outputs
output "metadata" {
  description = "Metadata"
  value = module.security_group.metadata
}
