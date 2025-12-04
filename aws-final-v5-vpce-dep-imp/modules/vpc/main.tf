resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge({ Name = var.name }, var.tags)
}

# resource "aws_internet_gateway" "igw" {
#   vpc_id = aws_vpc.this.id
#   tags = { Name = "${var.name}-igw" }
# }