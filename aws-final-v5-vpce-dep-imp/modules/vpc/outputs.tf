output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "cidr_block" {
  description = "VPC CIDR"
  value       = aws_vpc.this.cidr_block
}
