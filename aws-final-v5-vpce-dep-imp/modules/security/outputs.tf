
# SECURITY GROUP OUTPUTS
#########################

# Primary SG (main output)
output "security_group_id" {
  value       = aws_security_group.default.id
  description = "ID of the created or imported Security Group"
}

# Export all inbound rule IDs
output "inbound_rule_ids" {
  description = "Map of inbound rule IDs"
  value       = { for k, v in aws_security_group_rule.inbound : k => v.id }
}

# Export all outbound rule IDs
output "outbound_rule_ids" {
  description = "Map of outbound rule IDs"
  value       = { for k, v in aws_security_group_rule.outbound : k => v.id }
}
