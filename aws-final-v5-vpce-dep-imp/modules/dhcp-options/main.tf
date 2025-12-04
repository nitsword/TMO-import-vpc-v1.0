##############################################
# DHCP Options (Optional)
##############################################

# Local map to conditionally create the DHCP Options Set itself.
# It uses a key of "this" if enabled, otherwise it's an empty map.
locals {
  dhcp_options_map = var.dhcp_enabled ? { "this" : true } : {}
  
  # This map will contain one key ("assoc") if the association should exist.
  # Creation is skipped if import_mode is true, or if dhcp_enabled is false.
  association_map = (var.dhcp_enabled && !var.import_mode) ? { "assoc" : true } : {}
}

resource "aws_vpc_dhcp_options" "this" {
  for_each = local.dhcp_options_map
  
  # The try() function ensures we don't try to access null.domain_name if var.dhcp is null
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
# DHCP Options Association (Import-Friendly)
##############################################

resource "aws_vpc_dhcp_options_association" "assoc" {
  # Use for_each to make the resource address free of indices (no more [0])
  for_each = local.association_map

  vpc_id          = var.vpc_id
  # We must use one key from the for_each of aws_vpc_dhcp_options.this
  # Since it only creates one resource, we use the specific key "this".
  dhcp_options_id = aws_vpc_dhcp_options.this["this"].id
}