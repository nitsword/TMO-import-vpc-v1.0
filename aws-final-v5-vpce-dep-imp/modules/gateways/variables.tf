variable "vpc_id" {
  type        = string
  description = "VPC ID where IGW and NAT gateways will be created."
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming gateway resources."
}

variable "tags" {
  type        = map(string)
  description = "Common tags applied to all gateway resources."
  default     = {}
}

variable "public_subnet_ids_map" {
  type        = map(string)
  description = "Map of AZ key to public subnet IDs (used for public NAT gateways). Must contain keys 'a', 'b', and 'c' corresponding to the explicit resource blocks in main.tf."
}

variable "nonroutable_subnet_ids_map" {
  type        = map(string)
  description = "Map of AZ key to nonroutable subnet IDs (used for private NAT gateways). Must contain keys 'a', 'b', and 'c' corresponding to the explicit resource blocks in main.tf."
}