
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

# Collects all public subnet associations, keyed by availability zone letter (a, b, c).

output "public_associations" {
  description = "A map of public subnet association IDs, keyed by AZ letter."
  value = {
    for k, v in aws_network_acl_association.public_assoc : k => v.id
  }
}

# Collects all private subnet associations, keyed by availability zone letter (a, b, c).
output "private_tier_associations" {
  description = "A map of private subnet association IDs, keyed by AZ letter."
  value = {
    for k, v in aws_network_acl_association.private_assoc : k => v.id
  }
}

# Collects all nonroutable subnet associations, keyed by availability zone letter (a, b, c).
output "nonroutable_tier_associations" {
  description = "A map of nonroutable subnet association IDs, keyed by AZ letter."
  value = {
    for k, v in aws_network_acl_association.nonroutable_assoc : k => v.id
  }
}

# Combines all non-public associations (Private and Non-Routable) into a single map.
output "all_non_public_associations" {
  description = "Combined map of all Private and Non-Routable subnet association IDs, keyed by AZ letter."
  value = merge(
    { for k, v in aws_network_acl_association.private_assoc : k => v.id },
    { for k, v in aws_network_acl_association.nonroutable_assoc : k => v.id }
  )
}