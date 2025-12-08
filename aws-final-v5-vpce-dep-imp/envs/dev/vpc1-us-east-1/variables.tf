##############################################
# ENVIRONMENT VARIABLES
##############################################

variable "region" {
  type        = string
  description = "AWS region where this VPC will be deployed"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for naming all resources"
}

#################################################
# VPC CONFIG
#################################################

variable "vpc" {
  description = "VPC configuration"
  type = object({
    cidr = string
    tags = map(string)
  })
}

#################################################
# SUBNETS (public / private / nonroutable)
#################################################

variable "subnets" {
  description = "Subnet configuration for public, private, nonroutable"
  type = object({
    public = map(object({
      cidr = string
      az   = string
    }))
    private = map(object({
      cidr = string
      az   = string
    }))
    nonroutable = map(object({
      cidr = string
      az   = string
    }))
  })
}

#################################################
# NAT CONFIGURATION
#################################################

variable "nat" {
  description = "NAT gateway configuration"
  type = object({
    type = string # per_az or single
  })
}

#################################################
# ROUTE TABLE DEFINITIONS
#################################################

variable "route_tables" {
  description = "Route table definitions for public/private/nonroutable"
  type = object({
    public = object({
      routes = list(object({
        cidr   = string
        target = string
        az_key = optional(string)
      }))
    })
    private = object({
      routes = list(object({
        cidr   = string
        target = string
        az_key = optional(string)
      }))
    })
    nonroutable = object({
      routes = list(object({
        cidr   = string
        target = string
        az_key = optional(string)
      }))
    })
  })
}

#################################################
# DHCP OPTIONS
#################################################

variable "dhcp_enabled" {
  type        = bool
  description = "Enable DHCP options set"
  default     = false
}

variable "dhcp" {
  description = "DHCP options configuration"
  type = object({
    domain_name          = string
    domain_name_servers  = list(string)
    ntp_servers          = list(string)
    netbios_name_servers = list(string)
    netbios_node_type    = number
  })
}

#################################################
# SECURITY GROUP RULES
#################################################

variable "sg_rules" {
  description = "Security group rule definitions for inbound and outbound traffic"

  type = object({
    inbound = list(object({
      rule_no     = number
      description = string
      protocol    = string
      from        = number
      to          = number
      cidr        = string
    }))

    outbound = list(object({
      rule_no     = number
      description = string
      protocol    = string
      from        = number
      to          = number
      cidr        = string
    }))
  })

  default = {
    inbound  = []
    outbound = []
  }
}


#################################################
# NACL RULES
#################################################

variable "nacl_rules" {
  description = "NACL rule sets for public and private"
  type = object({
    public = list(object({
      rule_no  = number
      protocol = string
      from     = number
      to       = number
      cidr     = string
      egress   = bool
    }))
    private = list(object({
      rule_no  = number
      protocol = string
      from     = number
      to       = number
      cidr     = string
      egress   = bool
    }))
  })
}

#################################################
# VPC ENDPOINTS
#################################################

variable "vpc_endpoints" {
  description = "Enable/disable individual VPC endpoints"
  type = object({
    ssm         = bool
    ec2messages = bool
    s3          = bool
  })
}

#################################################
# GLOBAL TAGS
#################################################

variable "tags" {
  type        = map(string)
  description = "Global tags applied to all resources"
}

variable "availability_zone_keys" {
  description = "A static, set of keys "
  type        = set(string)
  # --- CHANGE IS HERE ---
  default     = ["a", "b", "c"]
  # ----------------------
}
