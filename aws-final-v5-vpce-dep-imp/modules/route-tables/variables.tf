

variable "vpc_id" {
  type        = string
  description = "VPC ID where route tables will be created"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming all route table resources"
}

#############################################
# Static Key Map
#############################################
variable "az_keys" {
  type        = list(string)
  description = "Ordered list of AZ keys (example: [\"a\", \"b\", \"c\"])"
}

#############################################
# Subnet ID Maps
#############################################

variable "public_subnet_ids_map" {
  type        = map(string)
  description = "Map of subnet IDs for public subnets"
}

variable "private_subnet_ids_map" {
  type        = map(string)
  description = "Map of subnet IDs for private subnets"
}

variable "nonroutable_subnet_ids_map" {
  type        = map(string)
  description = "Map of subnet IDs for non-routable subnets"
}

#############################################
# IGW & NAT Gateway Inputs
#############################################

variable "igw_id" {
  type        = string
  description = "Internet Gateway ID for public routing"
}

variable "public_nat_ids_map" {
  type        = map(string)
  description = "Map of Public NAT Gateway IDs keyed by AZ"
}

variable "private_nat_ids_map" {
  type        = map(string)
  description = "Map of Private NAT Gateway IDs keyed by AZ"
}

#############################################
# Route Definitions 
#############################################
variable "route_tables" {
  description = "Routing configuration for the public route table"
  type = object({
    public = object({
      routes = list(object({
        cidr   = string
        target = string   # Should be 'igw'
      }))
    })
  })
  default = {
    public = {
      routes = [
        # Default route to the Internet Gateway
        { cidr = "0.0.0.0/0", target = "igw" }
      ]
    }
  }
}


variable "skip_existing_routes" {
  type        = bool
  description = "Skip creation if route already exists in AWS"
  default     = true
}
