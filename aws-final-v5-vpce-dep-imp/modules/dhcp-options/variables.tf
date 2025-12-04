###############################################
# DHCP OPTIONS MODULE VARIABLES
###############################################

variable "vpc_id" {
  description = "The ID of the VPC to associate the DHCP Options Set with."
  type        = string
}

variable "dhcp_enabled" {
  description = "Set to true to create the DHCP Options Set and associate it with the VPC."
  type        = bool
  default     = false
}

variable "import_mode" {
  description = "If true, skips the creation of the association to avoid drift during import."
  type        = bool
  default     = false
}

variable "name_prefix" {
  description = "The prefix to use for resource naming."
  type        = string
}

variable "dhcp" {
  description = "Configuration settings for the VPC DHCP options."
  type = object({
    domain_name          = optional(string)
    domain_name_servers  = optional(list(string))
    ntp_servers          = optional(list(string))
    netbios_name_servers = optional(list(string))
    netbios_node_type    = optional(string)
  })
  default = {}
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}