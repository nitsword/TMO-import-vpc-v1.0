
# Subnets Module Outputs
#############################################


locals {

  raw_public_subnets = [
    try(aws_subnet.public_a[0], null),
    try(aws_subnet.public_b[0], null),
    try(aws_subnet.public_c[0], null)
  ]
  raw_private_subnets = [
    try(aws_subnet.private_a[0], null),
    try(aws_subnet.private_b[0], null),
    try(aws_subnet.private_c[0], null)
  ]
  raw_nonroutable_subnets = [
    try(aws_subnet.nonroutable_a[0], null),
    try(aws_subnet.nonroutable_b[0], null),
    try(aws_subnet.nonroutable_c[0], null)
  ]


  all_public_subnets      = [for s in local.raw_public_subnets : s if s != null]
  all_private_subnets     = [for s in local.raw_private_subnets : s if s != null]
  all_nonroutable_subnets = [for s in local.raw_nonroutable_subnets : s if s != null]


  subnet_keys = ["a", "b", "c"]

  
  
  public_subnets_map = {
    for i, s in local.all_public_subnets :
    local.subnet_keys[i] => s
  }
  private_subnets_map = {
    for i, s in local.all_private_subnets :
    local.subnet_keys[i] => s
  }
  nonroutable_subnets_map = {
    for i, s in local.all_nonroutable_subnets :
    local.subnet_keys[i] => s
  }
}

# Output the maps of IDs for the different tiers (now keyed by "a", "b", "c")
output "public_subnet_ids_map" {
  description = "A map of AZ suffix (a, b, c) => ID for all provisioned public subnets."
  value       = { for k, s in local.public_subnets_map : k => s.id }
}

output "private_subnet_ids_map" {
  description = "A map of AZ suffix (a, b, c) => ID for all provisioned private subnets."
  value       = { for k, s in local.private_subnets_map : k => s.id }
}

output "nonroutable_subnet_ids_map" {
  description = "A map of AZ suffix (a, b, c) => ID for all provisioned non-routable subnets."
  value       = { for k, s in local.nonroutable_subnets_map : k => s.id }
}


output "all_subnets" {
  description = "Consolidated list of all aws_subnet objects across all tiers."
  value       = flatten([local.all_public_subnets, local.all_private_subnets, local.all_nonroutable_subnets])
}


output "all_subnet_ids_map" {
  description = "Consolidated map containing the IDs of all subnets by tier (keyed by a, b, c)."
  value = {
    public      = { for k, s in local.public_subnets_map : k => s.id }
    private     = { for k, s in local.private_subnets_map : k => s.id }
    nonroutable = { for k, s in local.nonroutable_subnets_map : k => s.id }
  }
}


output "public_subnet_ids" {
  description = "A simple list of IDs for all provisioned public subnets."
  value       = [for s in local.all_public_subnets : s.id]
}

output "private_subnet_ids" {
  description = "A simple list of IDs for all provisioned private subnets."
  value       = [for s in local.all_private_subnets : s.id]
}

output "nonroutable_subnet_ids" {
  description = "A simple list of IDs for all provisioned non-routable subnets."
  value       = [for s in local.all_nonroutable_subnets : s.id]
}
