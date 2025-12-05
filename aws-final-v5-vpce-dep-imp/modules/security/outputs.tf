
# SECURITY GROUP OUTPUTS
#########################

# Primary SG (main output)
output "security_group_id" {
  value       = aws_security_group.default.id
  description = "ID of the created or imported Security Group"
}

# Export all inbound rule IDs (for debugging / import validation)
output "inbound_rule_ids" {
  description = "Map of inbound rule IDs keyed by the stable rule key (e.g., '001-ssh-from-internet')"
  value       = { for k, v in aws_security_group_rule.inbound : k => v.id }
}

# Export all outbound rule IDs (same behavior)
output "outbound_rule_ids" {
  description = "Map of outbound rule IDs keyed by the stable rule key (e.g., '001-all-traffic-out')"
  value       = { for k, v in aws_security_group_rule.outbound : k => v.id }
}