#############################################
# Subnets Module Variables (Import-Ready)
#############################################

variable "vpc_id" {
  type        = string
  description = "VPC ID where subnets will be created"
}

variable "name_prefix" {
  type        = string
  description = "Naming prefix applied to subnet resources"
}

variable "tags" {
  type        = map(string)
  description = "Base tags applied to all subnets"
  default     = {}
}

#############################################
# Subnet Definitions for 3 Network Tiers
#############################################

# NOTE:
# The module relies on fixed resource addresses (e.g., public_a, private_b).
# Therefore, map keys MUST be stable ('a', 'b', 'c').
# Tiers are optional (default to empty map {}) if no subnets are required
# for that tier.

variable "subnets" {
  description = "Subnet layout definition. All tier maps should use 'a', 'b', 'c' as keys."

  type = object({
    public = optional(map(object({
      cidr = string
      az   = string
    })), {})

    private = optional(map(object({
      cidr = string
      az   = string
    })), {})

    nonroutable = optional(map(object({
      cidr = string
      az   = string
    })), {})
  })
}