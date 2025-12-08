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


variable "inbound" {
  description = "List of inbound SG rule objects"
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
