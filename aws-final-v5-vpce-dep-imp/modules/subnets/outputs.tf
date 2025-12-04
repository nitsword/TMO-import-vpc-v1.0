#############################################
# Subnets Module Outputs
#############################################

# Helper locals to safely access subnet data, handling resources where count is 0.
locals {
  # 1. Gather all subnet objects (including nulls if count=0)
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

  # 2. Filter out nulls to get only created subnet objects
  all_public_subnets      = [for s in local.raw_public_subnets : s if s != null]
  all_private_subnets     = [for s in local.raw_private_subnets : s if s != null]
  all_nonroutable_subnets = [for s in local.raw_nonroutable_subnets : s if s != null]

  # 3. Define the standard keys (based on their position in the array)
  # This map must contain the index/key used by the consuming modules (e.g., "a", "b", "c")
  subnet_keys = ["a", "b", "c"]

  # Maps for easier lookup by a standard key ("a", "b", "c")
  # We iterate over the subnet objects and manually set the key based on its index
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

# 1. Output the maps of IDs for the different tiers (now keyed by "a", "b", "c")
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

# 2. Output the consolidated list of all subnet objects (for VPC peering/routing)
output "all_subnets" {
  description = "Consolidated list of all aws_subnet objects across all tiers."
  value       = flatten([local.all_public_subnets, local.all_private_subnets, local.all_nonroutable_subnets])
}

# 3. Output the consolidated map of all subnet IDs
output "all_subnet_ids_map" {
  description = "Consolidated map containing the IDs of all subnets by tier (keyed by a, b, c)."
  value = {
    public      = { for k, s in local.public_subnets_map : k => s.id }
    private     = { for k, s in local.private_subnets_map : k => s.id }
    nonroutable = { for k, s in local.nonroutable_subnets_map : k => s.id }
  }
}

# 4. Output the consolidated lists of IDs (for bulk association)
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