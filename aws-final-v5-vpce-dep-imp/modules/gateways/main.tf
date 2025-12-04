##############################################
# Gateways Module (AWS Provider v5 Compatible)
# Import-friendly version (Static Named Blocks)
##############################################

##############################################
# INTERNET GATEWAY
##############################################

resource "aws_internet_gateway" "igw" {
  vpc_id = var.vpc_id

  tags = merge(
    { Name = "${var.name_prefix}-igw" },
    var.tags
  )
}

##############################################
# PUBLIC NAT GATEWAYS (Internet Access)
# Using explicit blocks for easy import mapping (aws_nat_gateway.public_nat_a)
##############################################

# --- EIPs for Public NATs ---

resource "aws_eip" "public_nat_a" {
  domain = "vpc"
  tags = merge(
    { Name = "${var.name_prefix}-eip-public-a" },
    var.tags
  )
}

resource "aws_eip" "public_nat_b" {
  domain = "vpc"
  tags = merge(
    { Name = "${var.name_prefix}-eip-public-b" },
    var.tags
  )
}

resource "aws_eip" "public_nat_c" {
  domain = "vpc"
  tags = merge(
    { Name = "${var.name_prefix}-eip-public-c" },
    var.tags
  )
}

# --- Public NAT Gateways ---

resource "aws_nat_gateway" "public_nat_a" {
  allocation_id = aws_eip.public_nat_a.id
  # Subnet ID for AZ 'a' is looked up from the map: var.public_subnet_ids_map
  subnet_id = var.public_subnet_ids_map["a"]

  tags = merge(
    { Name = "${var.name_prefix}-nat-public-a" },
    var.tags
  )
}

resource "aws_nat_gateway" "public_nat_b" {
  allocation_id = aws_eip.public_nat_b.id
  subnet_id = var.public_subnet_ids_map["b"]

  tags = merge(
    { Name = "${var.name_prefix}-nat-public-b" },
    var.tags
  )
}

resource "aws_nat_gateway" "public_nat_c" {
  allocation_id = aws_eip.public_nat_c.id
  subnet_id = var.public_subnet_ids_map["c"]

  tags = merge(
    { Name = "${var.name_prefix}-nat-public-c" },
    var.tags
  )
}

##############################################
# PRIVATE NAT GATEWAYS (No Internet Access)
# Using explicit blocks for easy import mapping (aws_nat_gateway.private_nat_a)
##############################################

resource "aws_nat_gateway" "private_nat_a" {
  # No allocation_id needed for connectivity_type = "private"
  subnet_id = var.nonroutable_subnet_ids_map["a"]

  connectivity_type = "private"

  tags = merge(
    { Name = "${var.name_prefix}-nat-private-a" },
    var.tags
  )
}

resource "aws_nat_gateway" "private_nat_b" {
  subnet_id = var.nonroutable_subnet_ids_map["b"]

  connectivity_type = "private"

  tags = merge(
    { Name = "${var.name_prefix}-nat-private-b" },
    var.tags
  )
}

resource "aws_nat_gateway" "private_nat_c" {
  subnet_id = var.nonroutable_subnet_ids_map["c"]

  connectivity_type = "private"

  tags = merge(
    { Name = "${var.name_prefix}-nat-private-c" },
    var.tags
  )
}