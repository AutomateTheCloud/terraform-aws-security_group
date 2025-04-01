##-----------------------------------------------------------------------------
# provider: aws
# name:     security_group
# version:  1.11.0
##-----------------------------------------------------------------------------

##-----------------------------------------------------------------------------
# Terraform
terraform {
  required_version = "~> 1.11.0"
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.93"
      configuration_aliases = [aws.this]
    }
  }
}

##-----------------------------------------------------------------------------
# Data
data "aws_region" "this" {
  provider = aws.this
}

data "aws_caller_identity" "this" {
  provider = aws.this
}

##-----------------------------------------------------------------------------
# Variables
variable "details" {
  description = "Details"
  type        = any
  default = {
    scope            = ""
    scope_abbr       = ""
    purpose          = ""
    purpose_abbr     = ""
    environment      = ""
    environment_abbr = ""
    additional_tags  = {}
  }
}

##-----------------------------------------------------------------------------
# Validation
resource "null_resource" "validate-details_scope" {
  lifecycle {
    precondition {
      condition     = try(var.details.scope, "") != ""
      error_message = "Scope not specified."
    }
  }
}
resource "null_resource" "validate-details_purpose" {
  lifecycle {
    precondition {
      condition     = try(var.details.purpose, "") != ""
      error_message = "Purpose not specified."
    }
  }
}
resource "null_resource" "validate-details_environment" {
  lifecycle {
    precondition {
      condition     = try(var.details.environment, "") != ""
      error_message = "Environment not specified."
    }
  }
}

##-----------------------------------------------------------------------------
# Locals
locals {
  scope = {
    name    = var.details.scope
    abbr    = (can(var.details.scope_abbr) ? var.details.scope_abbr : lower(replace(replace(var.details.scope, "/[^0-9A-Za-z]/", " "), "/\\s{1,}/", "_")))
    machine = (can(var.details.scope_abbr) ? replace(var.details.scope_abbr, "/[^0-9A-Za-z]/", "") : lower(replace(var.details.scope, "/[^0-9A-Za-z]/", "")))
  }

  purpose = {
    name    = var.details.purpose
    abbr    = (can(var.details.purpose_abbr) ? var.details.purpose_abbr : lower(replace(replace(var.details.purpose, "/[^0-9A-Za-z]/", " "), "/\\s{1,}/", "_")))
    machine = (can(var.details.purpose_abbr) ? replace(var.details.purpose_abbr, "/[^0-9A-Za-z]/", "") : lower(replace(var.details.purpose, "/[^0-9A-Za-z]/", "")))
  }

  environment = {
    name    = var.details.environment
    abbr    = (can(var.details.environment_abbr) ? var.details.environment_abbr : lower(replace(replace(var.details.environment, "/[^0-9A-Za-z]/", " "), "/\\s{1,}/", "_")))
    machine = (can(var.details.environment_abbr) ? replace(var.details.environment_abbr, "/[^0-9A-Za-z]/", "") : lower(replace(var.details.environment, "/[^0-9A-Za-z]/", "")))
  }

  additional_tags = (try(var.details.additional_tags, {}))

  tags = merge(
    tomap({
      "Scope"       = local.scope.name,
      "Purpose"     = local.purpose.name,
      "Environment" = local.environment.name,
    }),
    local.additional_tags
  )

  aws = {
    account = {
      id = data.aws_caller_identity.this.account_id
    }
    region = {
      name        = data.aws_region.this.name
      abbr        = local.lookup.region.abbr["${data.aws_region.this.name}"]
      description = data.aws_region.this.description
    }
  }

  lookup = {
    region = {
      abbr = {
        af-south-1     = "afs1"
        ap-east-1      = "ape1"
        ap-northeast-1 = "apne1"
        ap-northeast-2 = "apne2"
        ap-northeast-3 = "apne3"
        ap-south-1     = "aps1"
        ap-south-2     = "aps2"
        ap-southeast-1 = "apse1"
        ap-southeast-2 = "apse2"
        ap-southeast-3 = "apse3"
        ap-southeast-4 = "apse4"
        ca-central-1   = "cac1"
        eu-central-1   = "euc1"
        eu-central-2   = "euc2"
        eu-north-1     = "eun1"
        eu-south-1     = "eus1"
        eu-south-2     = "eus2"
        eu-west-1      = "euw1"
        eu-west-2      = "euw2"
        eu-west-3      = "euw3"
        il-central-1   = "ilc1"
        me-central-1   = "mec1"
        me-south-1     = "mes1"
        sa-east-1      = "sae1"
        us-east-1      = "use1"
        us-east-2      = "use2"
        us-west-1      = "usw1"
        us-west-2      = "usw2"
        us-gov-east-1  = "uge1"
        us-gov-west-1  = "ugw1"
      }
    }
  }
}
