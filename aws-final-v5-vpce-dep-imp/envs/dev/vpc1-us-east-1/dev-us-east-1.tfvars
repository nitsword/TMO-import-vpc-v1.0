##################################################################
# ENVIRONMENT METADATA
##################################################################

name_prefix = "dev-us-east-1-vpc1"
region      = "us-east-1"

##################################################################
# VPC CONFIGURATION
##################################################################

vpc = {
  cidr = "10.65.0.0/16"

  tags = {
    Environment = "dev"
    Owner       = "network-team"
    Project     = "vpc1"
  }
}

##################################################################
# SUBNET CONFIGURATION
##################################################################

subnets = {
  public = {
    a = {
      cidr = "10.65.1.0/28"
      az   = "us-east-1a"
    }
    b = {
      cidr = "10.65.1.16/28"
      az   = "us-east-1b"
    }
    c = {
      cidr = "10.65.1.32/28"
      az   = "us-east-1c"
    }
  }

  private = {
    a = {
      cidr = "10.65.0.0/26"
      az   = "us-east-1a"
    }
    b = {
      cidr = "10.65.0.64/26"
      az   = "us-east-1b"
    }
    c = {
      cidr = "10.65.0.128/26"
      az   = "us-east-1c"
    }
  }

  nonroutable = {
    a = {
      cidr = "10.65.2.0/28"
      az   = "us-east-1a"
    }
    b = {
      cidr = "10.65.2.16/28"
      az   = "us-east-1b"
    }
    c = {
      cidr = "10.65.2.32/28"
      az   = "us-east-1c"
    }
  }
}

##################################################################
# NAT CONFIGURATION
##################################################################

nat = {
  type = "per_az"
}

##################################################################
# ROUTE TABLE DEFINITIONS (FIXED)
##################################################################

route_tables = {
  public = {
    routes = [
      {
        cidr   = "0.0.0.0/0"
        target = "igw"
      }
    ]
  }

  private = {
    routes = [
      {
        cidr   = "0.0.0.0/0"
        target = "nat"
        az_key = "a"
      },
      {
        cidr   = "0.0.0.0/0"
        target = "nat"
        az_key = "b"
      },
      {
        cidr   = "0.0.0.0/0"
        target = "nat"
        az_key = "c"
      }
    ]
  }

  nonroutable = {
    routes = [
      {
        cidr   = "10.0.0.0/8"
        target = "nat"
        az_key = "a"
      },
      {
        cidr   = "10.0.0.0/8"
        target = "nat"
        az_key = "b"
      },
      {
        cidr   = "10.0.0.0/8"
        target = "nat"
        az_key = "c"
      }
    ]
  }
}

##################################################################
# DHCP OPTIONS
##################################################################

dhcp_enabled = true

dhcp = {
  domain_name          = "example.internal"
  domain_name_servers  = ["10.0.0.2"]
  ntp_servers          = ["10.0.0.10"]
  netbios_name_servers = ["10.0.0.20"]
  netbios_node_type    = 2
}

##################################################################
# SG RULES
##################################################################

sg_rules = {
  inbound = [
    {
      rule_no     = 100
      description = "Allow HTTPS"
      protocol    = "tcp"
      from        = 443
      to          = 443
      cidr        = "0.0.0.0/0"
    },
    {
      rule_no     = 110
      description = "Allow SSH internal"
      protocol    = "tcp"
      from        = 22
      to          = 22
      cidr        = "10.0.0.0/8"
    }
  ]

  outbound = [
    {
      rule_no     = 100
      description = "Allow All outbound"
      protocol    = "-1"
      from        = 0
      to          = 0
      cidr        = "0.0.0.0/0"
    }
  ]
}



##################################################################
# NACL RULES
##################################################################

nacl_rules = {
  public = [
    {
      rule_no  = 100
      protocol = "6"
      from     = 443
      to       = 443
      cidr     = "0.0.0.0/0"
      egress   = true
    },
    {
      rule_no  = 110
      protocol = "6"
      from     = 1024
      to       = 65535
      cidr     = "0.0.0.0/0"
      egress   = false
    }
  ]

  private = [
    {
      rule_no  = 100
      protocol = "6"
      from     = 443
      to       = 443
      cidr     = "10.0.0.0/8"
      egress   = false
    },
    {
      rule_no  = 110
      protocol = "6"
      from     = 0
      to       = 65535
      cidr     = "10.0.0.0/8"
      egress   = true
    }
  ]
}

##################################################################
# VPC ENDPOINTS
##################################################################

vpc_endpoints = {
  ssm         = true
  ec2messages = true
  s3          = true
}

##################################################################
# GLOBAL TAGS
##################################################################

tags = {
  Environment = "dev"
  Application = "vpc1"
  Owner       = "network-team"
}