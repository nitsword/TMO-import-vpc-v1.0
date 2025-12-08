
# DHCP Options (Optional)

locals {
  dhcp_options_map = var.dhcp_enabled ? { "this" : true } : {}
  association_map = (var.dhcp_enabled && !var.import_mode) ? { "assoc" : true } : {}
}

resource "aws_vpc_dhcp_options" "this" {
  for_each = local.dhcp_options_map
  
 
  domain_name          = try(var.dhcp.domain_name, null)
  domain_name_servers  = try(var.dhcp.domain_name_servers, null)
  ntp_servers          = try(var.dhcp.ntp_servers, null)
  netbios_name_servers = try(var.dhcp.netbios_name_servers, null)
  netbios_node_type    = try(var.dhcp.netbios_node_type, null)

  tags = merge(
    {
      Name = "${var.name_prefix}-dhcp-options"
    },
    var.tags
  )
}

##############################################
# DHCP Options Association 
##############################################

resource "aws_vpc_dhcp_options_association" "assoc" {
 
  for_each = local.association_map

  vpc_id          = var.vpc_id
 
  dhcp_options_id = aws_vpc_dhcp_options.this["this"].id
}
