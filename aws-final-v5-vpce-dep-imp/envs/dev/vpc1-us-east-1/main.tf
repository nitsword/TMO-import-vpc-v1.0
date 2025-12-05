terraform {
  # This constraint allows any version 1.14.x, but not 1.15.0 or later.
    required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # This constraint allows any version 5.x.x, but not 6.0.0 or later.
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

##############################################
# VPC
##############################################

module "vpc" {
  source     = "../../../modules/vpc"
  name       = var.name_prefix
  cidr_block = var.vpc.cidr
  tags       = var.vpc.tags
}

##############################################
# SUBNETS
##############################################

module "subnets" {
  source      = "../../../modules/subnets"
  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix
  subnets     = var.subnets
  tags        = var.tags
}

##############################################
# GATEWAYS (NAT)
##############################################

##############################################
# GATEWAYS (IGW + NATs)
##############################################

# module "gateways" {
#   source = "../../../modules/gateways"

#   vpc_id      = module.vpc.vpc_id
#   name_prefix = var.name_prefix
#   tags        = var.tags

#   public_subnet_ids_map      = module.subnets.public_subnet_ids_map
#   nonroutable_subnet_ids_map = module.subnets.nonroutable_subnet_ids_map

#   # NEW REQUIRED FIELD
#   az_keys = keys(module.subnets.public_subnet_ids_map)
# }

module "gateways" {
  source = "../../../modules/gateways"

  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix
  tags        = var.tags

  public_subnet_ids_map      = module.subnets.public_subnet_ids_map
  nonroutable_subnet_ids_map = module.subnets.nonroutable_subnet_ids_map

}



##############################################
# ROUTE TABLES
##############################################

# module "rts" {
#   source = "../../../modules/route-tables"

#   vpc_id      = module.vpc.vpc_id
#   name_prefix = var.name_prefix

#   public_subnet_ids_map      = module.subnets.public_subnet_ids_map
#   private_subnet_ids_map     = module.subnets.private_subnet_ids_map
#   nonroutable_subnet_ids_map = module.subnets.nonroutable_subnet_ids_map

#   igw_id              = module.gateways.igw_id
#   public_nat_ids_map  = module.gateways.public_nat_map
#   private_nat_ids_map = module.gateways.private_nat_map

#   route_tables = var.route_tables

#   # NEW REQUIRED FIELD (same keys used everywhere)
#   az_keys = keys(module.subnets.public_subnet_ids_map)
# }

module "rts" {
  source = "../../../modules/route-tables"

  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix

  public_subnet_ids_map      = module.subnets.public_subnet_ids_map
  private_subnet_ids_map     = module.subnets.private_subnet_ids_map
  nonroutable_subnet_ids_map = module.subnets.nonroutable_subnet_ids_map

  igw_id              = module.gateways.igw_id
  public_nat_ids_map  = module.gateways.public_nat_map
  private_nat_ids_map = module.gateways.private_nat_map

  route_tables = var.route_tables

  az_keys = keys(module.subnets.public_subnet_ids_map)
}


##############################################
# NACLs (public + private)
##############################################
# private NACL applies to private + nonroutable subnets
##############################################

locals {
  nacl_rules_for_module = {
    public  = var.nacl_rules.public
    private = var.nacl_rules.private
  }
}

module "nacls" {
  source = "../../../modules/nacls"
  vpc_id       = module.vpc.vpc_id
  name_prefix  = var.name_prefix

  # FIX: Corrected map output names to match 'subnets/outputs.tf' 
  public_subnet_ids_map      = module.subnets.public_subnet_ids_map
  private_subnet_ids_map     = module.subnets.private_subnet_ids_map
  nonroutable_subnet_ids_map = module.subnets.nonroutable_subnet_ids_map

  # Static keys for 'for_each' dependency resolution
  public_subnet_keys         = var.availability_zone_keys 
  private_subnet_keys        = var.availability_zone_keys
  nonroutable_subnet_keys    = var.availability_zone_keys
}

##############################################
# DHCP OPTIONS
##############################################

module "dhcp" {
  source = "../../../modules/dhcp-options"

  name_prefix  = var.name_prefix
  vpc_id       = module.vpc.vpc_id
  dhcp_enabled = true # or var.dhcp_enabled

  dhcp = var.dhcp
}


##############################################
# SECURITY GROUP
##############################################

module "security" {
  source      = "../../../modules/security"
  vpc_id      = module.vpc.vpc_id
  name_prefix = var.name_prefix

  inbound  = var.sg_rules.inbound
  outbound = var.sg_rules.outbound

  tags = var.tags
}


##############################################
# VPC ENDPOINTS (FIXED)
##############################################

locals {
  interface_subnet_ids = values(module.subnets.private_subnet_ids_map)

  # FIX: Concatenate all Private and Nonroutable RT IDs from the new map outputs.
  gateway_route_table_ids = concat(
    values(module.rts.rt_private_ids),    # Retrieves all RT IDs for Private AZs (A, B, C)
    values(module.rts.rt_nonroutable_ids) # Retrieves all RT IDs for Nonroutable AZs (A, B, C)
  )
  endpoint_security_group_ids = [module.security.security_group_id]
}

module "vpc_endpoints" {
  source = "../../../modules/vpc-endpoints" # or ./modules/endpoints if that's your path

  vpc_id                  = module.vpc.vpc_id
  name_prefix             = var.name_prefix
  interface_subnet_ids    = local.interface_subnet_ids
  gateway_route_table_ids = local.gateway_route_table_ids
  security_group_ids          = local.endpoint_security_group_ids

  enabled = var.vpc_endpoints
  tags    = var.tags
}


##############################################
# OUTPUTS
##############################################

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnets" {
  value = module.subnets.public_subnet_ids_map
}

output "private_subnets" {
  value = module.subnets.private_subnet_ids_map
}

output "nonroutable_subnets" {
  value = module.subnets.nonroutable_subnet_ids_map
}