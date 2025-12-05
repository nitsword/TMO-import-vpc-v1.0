
# NACL Module (Fixed For_Each)
##################################


# PUBLIC NACL
# -----------------
resource "aws_network_acl" "public" {
  vpc_id = var.vpc_id

  # Tags are supported on the main NACL resource
  tags = merge(
    { Name = "${var.name_prefix}-nacl-public" },
    var.tags
  )

  # Ingress rules are dynamically defined based on input variable
  dynamic "ingress" {
    for_each = try(var.nacl_rules.public_ingress, [])
    content {
      rule_no    = ingress.value.rule_no
      protocol   = ingress.value.protocol
      action     = "allow"
      cidr_block = ingress.value.cidr
      from_port  = ingress.value.from
      to_port    = ingress.value.to
    }
  }

  # Egress rules are dynamically defined based on input variable
  dynamic "egress" {
    for_each = try(var.nacl_rules.public_egress, [])
    content {
      rule_no    = egress.value.rule_no
      protocol   = egress.value.protocol
      action     = "allow"
      cidr_block = egress.value.cidr
      from_port  = egress.value.from
      to_port    = egress.value.to
    }
  }
}


# PUBLIC NACL ASSOCIATIONS (FIXED DYNAMIC KEYS)

# -------------------------------------------
resource "aws_network_acl_association" "public_assoc" {
  # Use the static set of keys for iteration (known at plan time)
  for_each = var.public_subnet_keys

  network_acl_id = aws_network_acl.public.id
  # Use the known key (each.key) to look up the dynamic ID value (unknown until apply)
  subnet_id      = var.public_subnet_ids_map[each.key]
}



# PRIVATE NACL
# -------------------------------------------
resource "aws_network_acl" "private" {
  vpc_id = var.vpc_id

  # Tags are supported on the main NACL resource
  tags = merge(
    { Name = "${var.name_prefix}-nacl-private" },
    var.tags
  )

  # Ingress rules are dynamically defined based on input variable
  dynamic "ingress" {
    for_each = try(var.nacl_rules.private_ingress, [])
    content {
      rule_no    = ingress.value.rule_no
      protocol   = ingress.value.protocol
      action     = "allow"
      cidr_block = ingress.value.cidr
      from_port  = ingress.value.from
      to_port    = ingress.value.to
    }
  }

  # Egress rules are dynamically defined based on input variable
  dynamic "egress" {
    for_each = try(var.nacl_rules.private_egress, [])
    content {
      rule_no    = egress.value.rule_no
      protocol   = egress.value.protocol
      action     = "allow"
      cidr_block = egress.value.cidr
      from_port  = egress.value.from
      to_port    = egress.value.to
    }
  }
}


# PRIVATE NACL ASSOCIATIONS (FIXED DYNAMIC KEYS)
# -------------------------------------------
resource "aws_network_acl_association" "private_assoc" {

  for_each = var.private_subnet_keys

  network_acl_id = aws_network_acl.private.id

  subnet_id      = var.private_subnet_ids_map[each.key]
}


# NON-ROUTABLE NACL ASSOCIATIONS (FIXED DYNAMIC KEYS)
# -------------------------------------------
resource "aws_network_acl_association" "nonroutable_assoc" {

  for_each = var.nonroutable_subnet_keys

  network_acl_id = aws_network_acl.private.id 

  subnet_id      = var.nonroutable_subnet_ids_map[each.key]
}