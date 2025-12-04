#############################################
# Route Tables Outputs (Import-Friendly)
#############################################

# Public Route Table (Single Resource)
output "rt_public_id" {
  description = "ID of public route table"
  value       = aws_route_table.public.id
}

# Private Route Tables (Map by AZ Key)
# Explicitly map the fixed AZ keys to the explicitly named resources.
output "rt_private_ids" {
  description = "Private route table IDs keyed by AZ (e.g., a, b, c)"
  value = {
    "a" = aws_route_table.private_a.id
    "b" = aws_route_table.private_b.id
    "c" = aws_route_table.private_c.id
  }
}

# Non-routing route tables (Map by AZ Key)
# Explicitly map the fixed AZ keys to the explicitly named resources.
output "rt_nonroutable_ids" {
  description = "Non-routable route table IDs keyed by AZ"
  value = {
    "a" = aws_route_table.nonroutable_a.id
    "b" = aws_route_table.nonroutable_b.id
    "c" = aws_route_table.nonroutable_c.id
  }
}

#############################################
# Extended Outputs (Optional but helpful)
#############################################

# Expose full object maps for modules needing metadata
output "rt_private_objects" {
  description = "Full private route table objects keyed by AZ"
  value = {
    "a" = aws_route_table.private_a
    "b" = aws_route_table.private_b
    "c" = aws_route_table.private_c
  }
}

output "rt_nonroutable_objects" {
  description = "Full nonroutable route table objects keyed by AZ"
  value = {
    "a" = aws_route_table.nonroutable_a
    "b" = aws_route_table.nonroutable_b
    "c" = aws_route_table.nonroutable_c
  }
}