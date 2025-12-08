
# Route Tables Module 
######################### 


data "aws_vpc" "current" {
  id = var.vpc_id
}


# PUBLIC ROUTE TABLE
##########################################

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-public"
  }
}

# Create only IGW routes for public RT

resource "aws_route" "public_routes" {
  for_each = {
    for r in var.route_tables.public.routes : "${r.cidr}" => r
    if r.target == "igw"
  }

  route_table_id         = aws_route_table.public.id
  destination_cidr_block = each.value.cidr
  gateway_id             = var.igw_id
}

# --- PUBLIC ROUTE TABLE ASSOCIATIONS
resource "aws_route_table_association" "public_assoc_a" {
  subnet_id      = var.public_subnet_ids_map["a"]
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_assoc_b" {
  subnet_id      = var.public_subnet_ids_map["b"]
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_assoc_c" {
  subnet_id      = var.public_subnet_ids_map["c"]
  route_table_id = aws_route_table.public.id
}


# PRIVATE ROUTE TABLES 
##########################################

# --- Private Route Tables ---
resource "aws_route_table" "private_a" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-private-a"
  }
}
resource "aws_route_table" "private_b" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-private-b"
  }
}
resource "aws_route_table" "private_c" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-private-c"
  }
}


# --- Private Routes (Pointing to Public NAT GWs) ---
resource "aws_route" "private_routes_a" {
  route_table_id         = aws_route_table.private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.public_nat_ids_map["a"]
  timeouts {
    create = "5m"
  }
}
resource "aws_route" "private_routes_b" {
  route_table_id         = aws_route_table.private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.public_nat_ids_map["b"]
  timeouts {
    create = "5m"
  }
}
resource "aws_route" "private_routes_c" {
  route_table_id         = aws_route_table.private_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.public_nat_ids_map["c"]
  timeouts {
    create = "5m"
  }
}

# --- Private Route Table Associations ---
resource "aws_route_table_association" "private_assoc_a" {
  subnet_id      = var.private_subnet_ids_map["a"]
  route_table_id = aws_route_table.private_a.id
}
resource "aws_route_table_association" "private_assoc_b" {
  subnet_id      = var.private_subnet_ids_map["b"]
  route_table_id = aws_route_table.private_b.id
}
resource "aws_route_table_association" "private_assoc_c" {
  subnet_id      = var.private_subnet_ids_map["c"]
  route_table_id = aws_route_table.private_c.id
}



# NON-ROUTABLE ROUTE TABLES 
##########################################

# --- Non-Routable Route Tables ---
resource "aws_route_table" "nonroutable_a" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-nonroutable-a"
  }
}
resource "aws_route_table" "nonroutable_b" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-nonroutable-b"
  }
}
resource "aws_route_table" "nonroutable_c" {
  vpc_id = var.vpc_id
  tags = {
    Name = "${var.name_prefix}-rt-nonroutable-c"
  }
}


# --- Non-Routable Routes 
resource "aws_route" "nonroutable_routes_a" {
  route_table_id         = aws_route_table.nonroutable_a.id
  destination_cidr_block = "0.0.0.0/0" 
  nat_gateway_id         = var.private_nat_ids_map["a"]
  timeouts {
    create = "5m"
  }
}
resource "aws_route" "nonroutable_routes_b" {
  route_table_id         = aws_route_table.nonroutable_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.private_nat_ids_map["b"]
  timeouts {
    create = "5m"
  }
}
resource "aws_route" "nonroutable_routes_c" {
  route_table_id         = aws_route_table.nonroutable_c.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.private_nat_ids_map["c"]
  timeouts {
    create = "5m"
  }
}

# --- Non-Routable Route Table Associations ---
resource "aws_route_table_association" "nonroutable_assoc_a" {
  subnet_id      = var.nonroutable_subnet_ids_map["a"]
  route_table_id = aws_route_table.nonroutable_a.id
}
resource "aws_route_table_association" "nonroutable_assoc_b" {
  subnet_id      = var.nonroutable_subnet_ids_map["b"]
  route_table_id = aws_route_table.nonroutable_b.id
}
resource "aws_route_table_association" "nonroutable_assoc_c" {
  subnet_id      = var.nonroutable_subnet_ids_map["c"]
  route_table_id = aws_route_table.nonroutable_c.id
}
