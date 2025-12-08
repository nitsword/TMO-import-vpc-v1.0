
# DHCP Options Module - Outputs (Import Safe)


output "dhcp_options_id" {
  description = "ID of the DHCP options set (null if not created)."
  value       = try(aws_vpc_dhcp_options.this["this"].id, null)
}


output "dhcp_association_status" {
  description = "DHCP options association"
  # The map will have 1 element if created, 0 otherwise.
  value       = length(aws_vpc_dhcp_options_association.assoc) > 0
}

output "dhcp_association_details" {
  description = "Details of DHCP association."
  value = try(
    {
      vpc_id          = aws_vpc_dhcp_options_association.assoc["assoc"].vpc_id
      dhcp_options_id = aws_vpc_dhcp_options_association.assoc["assoc"].dhcp_options_id
    },
    null
  )
}
