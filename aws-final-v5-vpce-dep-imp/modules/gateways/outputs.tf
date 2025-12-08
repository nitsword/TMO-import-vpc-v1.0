### output.tf 



# Internet Gateway ID
output "igw_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.igw.id
}


output "public_nat_map" {
  description = "Maping Public NAT Gateway IDs"
  value = {
    "a" = aws_nat_gateway.public_nat_a.id
    "b" = aws_nat_gateway.public_nat_b.id
    "c" = aws_nat_gateway.public_nat_c.id
  }
}

output "private_nat_map" {
  description = "Map Private NAT Gateway IDs"
  value = {
    "a" = aws_nat_gateway.private_nat_a.id
    "b" = aws_nat_gateway.private_nat_b.id
    "c" = aws_nat_gateway.private_nat_c.id
  }
}

output "public_nat_eip_map" {
  description = "Map Public NAT Gateway EIP Allocation IDs."
  value = {
    "a" = aws_eip.public_nat_a.id
    "b" = aws_eip.public_nat_b.id
    "c" = aws_eip.public_nat_c.id
  }
}
