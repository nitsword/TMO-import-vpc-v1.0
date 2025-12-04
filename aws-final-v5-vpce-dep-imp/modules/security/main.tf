##############################################
# SECURITY GROUP MODULE (Import-Safe)
##############################################

resource "aws_security_group" "default" {
  name        = "${var.name_prefix}-sg"
  description = "Security group managed by Terraform module"
  vpc_id      = var.vpc_id

  tags = merge(
    { Name = "${var.name_prefix}-sg" },
    var.tags
  )
}

##############################################
# RULE KEY NORMALIZATION (Crucial for Stability)
# We normalize the input list of rules into a map with stable keys
# (rule_no + description) to prevent rule resource addresses from changing
# if the input list order is modified.
##############################################

locals {
  # Map: "001-ssh-from-internet" => rule_object
  inbound_rules_map = {
    for r in var.inbound :
    format("%03d-%s", r.rule_no, r.description) => r
  }

  # Map: "001-all-traffic-out" => rule_object
  outbound_rules_map = {
    for r in var.outbound :
    format("%03d-%s", r.rule_no, r.description) => r
  }
}

##############################################
# INBOUND RULES (Dedicated Resources via for_each)
##############################################

# NOTE: Using 'for_each' on a map of rules is the best practice for 
# managing SG rules, as it prevents drift and allows imports.
resource "aws_security_group_rule" "inbound" {
  for_each = local.inbound_rules_map

  type              = "ingress"
  security_group_id = aws_security_group.default.id

  protocol          = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  description       = each.value.description

  # Conditional arguments: Only one of these can be set.
  cidr_blocks              = try(each.value.cidr, null) != null ? [each.value.cidr] : null
  self                     = try(each.value.self, false)
  source_security_group_id = try(each.value.source_security_group_id, null)
}

##############################################
# OUTBOUND RULES (Dedicated Resources via for_each)
##############################################

# NOTE: Using 'for_each' on a map of rules is the best practice for 
# managing SG rules, as it prevents drift and allows imports.
resource "aws_security_group_rule" "outbound" {
  for_each = local.outbound_rules_map

  type              = "egress"
  security_group_id = aws_security_group.default.id

  protocol          = each.value.protocol
  from_port         = each.value.from
  to_port           = each.value.to
  description       = each.value.description

  # Conditional arguments: Only one of these can be set.
  cidr_blocks              = try(each.value.cidr, null) != null ? [each.value.cidr] : null
  self                     = try(each.value.self, false)
  source_security_group_id = try(each.value.source_security_group_id, null)
}