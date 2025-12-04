##############################################
# CORE VARIABLES
##############################################

variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming the Security Group"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to the security group"
}

##############################################
# RULE DEFINITIONS
##############################################

# NOTE: The 'cidr', 'self', and 'source_security_group_id' attributes 
# are made optional to allow rules using SGs instead of CIDR blocks, 
# which prevents conflicts in the aws_security_group_rule resource.

variable "inbound" {
  description = "List of inbound SG rule objects"
  type = list(object({
    rule_no                  = number
    description              = string
    protocol                 = string
    from                     = number
    to                       = number
    cidr                     = optional(string) # CIDR block or IP range
    self                     = optional(bool)   # Allow traffic from this SG itself
    source_security_group_id = optional(string) # Allow traffic from another SG
  }))
}

variable "outbound" {
  description = "List of outbound SG rule objects"
  type = list(object({
    rule_no                  = number
    description              = string
    protocol                 = string
    from                     = number
    to                       = number
    cidr                     = optional(string)
    self                     = optional(bool)
    source_security_group_id = optional(string)
  }))
}