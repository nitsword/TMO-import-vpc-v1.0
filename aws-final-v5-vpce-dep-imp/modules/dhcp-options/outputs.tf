##############################################
# DHCP Options Module - Outputs (Import Safe)
##############################################

# Use try() to safely retrieve the ID. Returns null if the DHCP Options set
# was not created (i.e., dhcp_enabled = false)
output "dhcp_options_id" {
  description = "ID of the DHCP options set (null if not created)."
  value       = try(aws_vpc_dhcp_options.this["this"].id, null)
}

# Returns a boolean indicating whether the association resource exists.
# The resource exists only if dhcp_enabled = true AND import_mode = false.
output "dhcp_association_status" {
  description = "Whether the DHCP options association resource was created in this run."
  # The map will have 1 element if created, 0 otherwise.
  value       = length(aws_vpc_dhcp_options_association.assoc) > 0
}

# Returns the association details or null if the association was not created.
output "dhcp_association_details" {
  description = "Details of DHCP association (null if not created)."
  value = try(
    {
      vpc_id          = aws_vpc_dhcp_options_association.assoc["assoc"].vpc_id
      dhcp_options_id = aws_vpc_dhcp_options_association.assoc["assoc"].dhcp_options_id
    },
    null
  )
}