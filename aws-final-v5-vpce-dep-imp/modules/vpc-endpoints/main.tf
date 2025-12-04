###############################################
# VPC ENDPOINTS MODULE (Import-Safe Version)
###############################################

data "aws_region" "current" {}

###############################################
# NORMALIZE ENABLED FLAGS → STABLE MAPS
###############################################

locals {
  # Map user's single 'ssm = true' flag to the required SSM interface endpoints.
  required_services = merge(
    var.enabled.s3 ? { s3 = "s3" } : {},
    var.enabled.ssm ? {
      # The 'ssm-messages' service name is often invalid in many regions, 
      # and 'ssm' + 'ec2messages' are sufficient for full SSM functionality.
      ssm         = "ssm"
      ec2messages = "ec2messages"
      # REMOVED: ssm_messages = "ssm-messages"
    } : {}
  )

  # Separate Interface-type services
  interface_services = {
    for k, v in local.required_services : k => v
    if v != "s3"
  }

  # Separate Gateway-type services
  gateway_services = {
    for k, v in local.required_services : k => v
    if v == "s3"
  }
}

###############################################
# INTERFACE TYPE ENDPOINTS (SSM, EC2MESSAGES)
###############################################

resource "aws_vpc_endpoint" "interface" {
  # Uses local.interface_services to conditionally create endpoints
  for_each = local.interface_services

  vpc_id              = var.vpc_id
  # Service name convention: 'com.amazonaws.<region>.<service>'
  service_name        = "com.amazonaws.${data.aws_region.current.name}.${each.value}"
  vpc_endpoint_type   = "Interface"

  # Required for Interface Endpoints
  security_group_ids  = var.security_group_ids
  subnet_ids          = var.interface_subnet_ids
  private_dns_enabled = true

  tags = merge(
    {
      Name = "${var.name_prefix}-vpce-${each.key}"
      Type = "interface"
    },
    var.tags
  )
}

###############################################
# S3 GATEWAY ENDPOINT
###############################################

resource "aws_vpc_endpoint" "gateway" {
  # Uses local.gateway_services to conditionally create the S3 endpoint
  for_each = local.gateway_services

  vpc_id              = var.vpc_id
  # Service name for S3 Gateway is just 's3'
  service_name        = "com.amazonaws.${data.aws_region.current.name}.s3"
  vpc_endpoint_type   = "Gateway"

  route_table_ids = var.gateway_route_table_ids

  tags = merge(
    {
      # Use the key as part of the name to maintain a dynamic prefix
      Name = "${var.name_prefix}-vpce-${each.key}"
      Type = "gateway"
    },
    var.tags
  )
}