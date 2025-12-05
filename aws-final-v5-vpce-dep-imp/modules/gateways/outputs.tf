### output.tf 



# Internet Gateway ID
output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}

# Map of AZ key → Public NAT Gateway IDs (for private subnets)
output "public_nat_map" {
  description = "Map of AZ key → Public NAT Gateway IDs (used by private subnets)"
  value = {
    "a" = aws_nat_gateway.public_nat_a.id
    "b" = aws_nat_gateway.public_nat_b.id
    "c" = aws_nat_gateway.public_nat_c.id
  }
}

# Map of AZ key → Private NAT Gateway IDs (for nonroutable subnets)
output "private_nat_map" {
  description = "Map of AZ key → Private NAT Gateway IDs (used by nonroutable subnets)"
  value = {
    "a" = aws_nat_gateway.private_nat_a.id
    "b" = aws_nat_gateway.private_nat_b.id
    "c" = aws_nat_gateway.private_nat_c.id
  }
}

# Map of AZ key → Public NAT Gateway EIP IDs
output "public_nat_eip_map" {
  description = "Map of AZ key → Public NAT Gateway EIP Allocation IDs."
  value = {
    "a" = aws_eip.public_nat_a.id
    "b" = aws_eip.public_nat_b.id
    "c" = aws_eip.public_nat_c.id
  }
}