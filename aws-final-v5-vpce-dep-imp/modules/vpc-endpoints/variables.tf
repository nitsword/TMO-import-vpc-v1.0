###############################################
# VPC ENDPOINTS MODULE VARIABLES
###############################################

variable "vpc_id" {
  description = "The VPC ID to deploy the endpoints into."
  type        = string
}

variable "interface_subnet_ids" {
  description = "A list of subnet IDs for interface endpoints (SSM/EC2/etc.)."
  type        = list(string)
}

variable "gateway_route_table_ids" {
  description = "A list of route table IDs for gateway endpoints (S3)."
  type        = list(string)
}

variable "security_group_ids" {
  description = "A list of security group IDs to associate with the interface endpoints."
  # This MUST be a list(string) or set(string)
  type        = list(string)
}

variable "name_prefix" {
  description = "The prefix to use for resource naming."
  type        = string
}

variable "enabled" {
  description = "Map of services to enable (ssm and s3 are supported)."
  type = object({
    ssm = bool
    s3  = bool
  })
  default = {
    ssm = false
    s3  = false
  }
}

variable "tags" {
  description = "A map of tags to assign to the resources."
  type        = map(string)
  default     = {}
}