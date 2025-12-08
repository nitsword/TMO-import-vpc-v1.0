#######################
# VPC Module Variables 
####################################################

# Existing naming remains unchanged
variable "name" {
  description = "Name prefix for VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "tags" {
  description = "Tags applied to VPC"
  type        = map(string)
  default     = {}
}

####################################################
# Optional enhancements
####################################################

variable "enable_dns_support" {
  description = "Enable DNS resolution in the VPC"
  type        = bool
  default     = true
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

####################################################
# Import Mode Support
####################################################
variable "existing_vpc_id" {
  description = "check th existing vpc"
  type    = string
  default = ""
}
