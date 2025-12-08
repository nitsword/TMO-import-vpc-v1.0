
# NACL Module Outputs
##################################

# --- NACL IDs ---

output "public_nacl_id" {
  description = "The ID of the Public Network ACL."
  value       = aws_network_acl.public.id
}

output "private_nacl_id" {
  description = "The ID of the Private/Non-routable Network ACL."
  value       = aws_network_acl.private.id
}

# --- NACL Association IDs ---


output "public_associations" {
  description = "public subnet association ID"
  value = {
    for k, v in aws_network_acl_association.public_assoc : k => v.id
  }
}

#private subnet associations
output "private_tier_associations" {
  description = "private subnet association IDs"
  value = {
    for k, v in aws_network_acl_association.private_assoc : k => v.id
  }
}


output "nonroutable_tier_associations" {
  description = "nonroutable subnet association ID"
  value = {
    for k, v in aws_network_acl_association.nonroutable_assoc : k => v.id
  }
}


output "all_non_public_associations" {
  description = "Private and Non-Routable subnet association ID"
  value = merge(
    { for k, v in aws_network_acl_association.private_assoc : k => v.id },
    { for k, v in aws_network_acl_association.nonroutable_assoc : k => v.id }
  )
}
