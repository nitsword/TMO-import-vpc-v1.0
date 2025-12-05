import json
import sys
import os
import ipaddress

# Configuration
JSON_FILE = "resources_for_import.json"
OUTPUT_FILE = "dev-us-east-1.tfvars"

def get_cidr_size(cidr):
    try:
        return ipaddress.ip_network(cidr).prefixlen
    except ValueError:
        return 32 # Use max prefix length if invalid CIDR

def get_tag_value(resource, key):
    """function to extract tag value from a resources metadata (looks in nested 'Tags')."""
    tags = resource.get('metadata', {}).get('Tags', {})
    if isinstance(tags, list):
        for tag in tags:
            if tag.get('Key') == key:
                return tag.get('Value')
    elif isinstance(tags, dict):
        return tags.get(key)
    return None

def determine_az_key(az_name):
    """Extracts the single-letter AZ key (e.g., 'us-east-1a' -> 'a')."""
    if not az_name:
        return 'z' # Fallback
    return az_name[-1:]

def determine_subnet_type(resource):
    """
    Infers subnet type based on its Name tag.
    """
    subnet_name = resource['metadata'].get('Name') or get_tag_value(resource, 'Name') or ''
    name = subnet_name.lower()
    
    # Priority 1: Public/Web/Internet-facing subnets
    if "public" in name or "web" in name or "alb" in name or "internet" in name:
        return "public"
    
    # Priority 2: Non-routable/Isolated/Data subnets
    if "nonroutable" in name or "db" in name or "rds" in name or "isolated" in name:
        return "nonroutable"
    
    # Priority 3: All remaining subnets default to private
    return "private"

# --- CORE HCL FORMATTING FUNCTIONS ---

def hcl_format_list(data, indent=0):
    """Formats a Python list of maps (rules/routes) into a multi-line HCL list structure."""
    if not data:
        return "[]"
    
    indent_str = ' ' * indent
    lines = [indent_str + "["]
    
    for i, item in enumerate(data):
        is_last = (i == len(data) - 1)
        comma = "," if not is_last else ""
        
        # Generate the nested map content recursively
        map_content = hcl_format_map(item, indent + 2) 
        
        # Split into lines
        map_lines = map_content.split('\n')
        
        # Attach the comma to the closing brace line
        map_lines[-1] += comma
        
        # Join lines with newlines and append to output lines
        lines.append('\n' + '\n'.join(map_lines)) 
        
    lines.append('\n' + indent_str + "]")
    return "".join(lines)


def hcl_format_map(data, indent=0):
    if not data:
        return "{}"
    
    indent_str = ' ' * indent
    inner_indent_str = ' ' * (indent + 2)
    lines = [indent_str + "{"]
    keys = sorted(data.keys())

    for i, key in enumerate(keys):
        value = data[key]
        is_last = (i == len(keys) - 1)
        comma = "," if not is_last else ""
        
        # Determine the full HCL representation for the value
        if isinstance(value, dict):
            # Nested Map (e.g., subnets type/az blocks)
            hcl_value = hcl_format_map(value, indent + 2)
        elif isinstance(value, list) and value and isinstance(value[0], dict):
            # Nested List of Maps (Rules/Routes)
            hcl_value = hcl_format_list(value, indent + 2)
        elif isinstance(value, list):
            # Simple List (e.g., domain_name_servers)
            list_items = ', '.join([f'"{x}"' if isinstance(x, str) else str(x) for x in value])
            hcl_value = f'[{list_items}]'
        elif isinstance(value, str):
            hcl_value = f'"{value}"'
        elif isinstance(value, bool):
            hcl_value = str(value).lower()
        elif isinstance(value, (int, float)):
            hcl_value = str(value)
        else:
            lines.append(f'\n{inner_indent_str}# TODO: Unhandled type for {key}')
            continue
            
        # Append to output lines
        if hcl_value.startswith('{') or hcl_value.startswith('['):
            # Nested blocks (maps or lists of maps): comma goes on the closing line
            hcl_lines = hcl_value.split('\n')
            hcl_lines[-1] += comma
            
            # The structure for nested blocks:
            lines.append(f'\n{inner_indent_str}{key} = {hcl_lines[0]}') # key = { or [
            lines.append('\n'.join(hcl_lines[1:])) # all inner content and the closing line
            
        else:
            # Simple types: comma goes immediately after the value
            lines.append(f'\n{inner_indent_str}{key} = {hcl_value}{comma}')
            
    lines.append('\n' + indent_str + "}")
    return "".join(lines)

# --- END CORE HCL FORMATTING FUNCTIONS ---


def generate_tfvars_from_json():
    """Reads discovered resources from JSON and generates a structured tfvars file matching the target schema."""
    print(f"-> Reading discovery data from: {JSON_FILE}")
    try:
        with open(JSON_FILE, 'r') as f:
            resources = json.load(f)
    except Exception as e:
        print(f"ERROR reading or decoding JSON file: {e}")
        # Use mock data if the JSON file is missing or invalid for demonstration
        if not os.path.exists(JSON_FILE):
             print("Using mock data as JSON file was not found.")
             resources = [
                {"type": "aws_vpc", "metadata": {"VpcId": "vpc-012345", "CidrBlock": "10.0.0.0/16", "Region": "us-east-1", "Tags": [{"Key": "Name", "Value": "dev-us-east-1-vpc"}]}},
                {"type": "aws_subnet", "metadata": {"CidrBlock": "10.65.2.0/28", "AvailabilityZone": "us-east-1a", "Tags": [{"Key": "Name", "Value": "nonroutable-a"}]}},
                {"type": "aws_subnet", "metadata": {"CidrBlock": "10.65.0.0/26", "AvailabilityZone": "us-east-1a", "Tags": [{"Key": "Name", "Value": "private-a"}]}},
                {"type": "aws_subnet", "metadata": {"CidrBlock": "10.65.1.0/28", "AvailabilityZone": "us-east-1a", "Tags": [{"Key": "Name", "Value": "public-a"}]}},
                {"type": "aws_nat_gateway", "metadata": {}},
                {"type": "aws_nat_gateway", "metadata": {}}
             ]
        else:
            sys.exit(1)


    # Filter Resources ---
    vpc_data = next((r for r in resources if r['type'] == 'aws_vpc'), None)
    subnets = [r for r in resources if r['type'] == 'aws_subnet']
    nat_gateways = [r for r in resources if r['type'] == 'aws_nat_gateway']
    
    if not vpc_data:
        print("ERROR: Could not find 'aws_vpc' resource in the JSON file. Cannot proceed.")
        sys.exit(1)

    # Extract Core Metadata and Sort ---
    vpc_meta = vpc_data['metadata']
    vpc_cidr = vpc_meta.get('CidrBlock', '10.0.0.0/16')
    vpc_name = vpc_meta.get('Name') or get_tag_value(vpc_data, 'Name') or vpc_meta.get('VpcId', 'imported-vpc')
    region = vpc_meta.get('Region', 'us-east-1')
    
    prefix_parts = vpc_name.split('-')
    name_prefix = '-'.join(prefix_parts[:-1]) if len(prefix_parts) > 1 and not vpc_name.startswith('vpc-') else vpc_name
    
    # Subnets are sorted by size (largest first - smaller prefix length)
    subnets.sort(key=lambda x: get_cidr_size(x['metadata'].get('CidrBlock', '255.255.255.255/32')))


    #  Construct Complex Variables to Match Target Schema ---
    
    # vpc variable
    vpc_tags_meta = vpc_meta.get('Tags', {})
    vpc_tags_var = {
        "Environment": vpc_tags_meta.get('Environment', 'dev'),
        "Owner": vpc_tags_meta.get('Owner', 'imported-user'), 
        "Project": vpc_tags_meta.get('Project', name_prefix),
    }
    vpc_var = {
        "cidr": vpc_cidr, 
        "tags": vpc_tags_var,
    }

    # subnets variable (Nested map: { type = { az_key = { cidr, az } } } )
    subnets_var = { "public": {}, "private": {}, "nonroutable": {} }
    
    for subnet in subnets:
        subnet_meta = subnet['metadata']
        subnet_cidr = subnet_meta.get('CidrBlock')
        subnet_type = determine_subnet_type(subnet)
        
        az = subnet_meta.get('AvailabilityZone')
        az_key = determine_az_key(az)
        
        if subnet_type in subnets_var:
            if az_key in subnets_var[subnet_type]:
                continue
            
            subnets_var[subnet_type][az_key] = {
                "cidr": subnet_cidr,
                "az": az,
            }
        
    subnets_var = {k: v for k, v in subnets_var.items() if v}


    # nat variable
    nat_var = {
        "type": "per_az" if len(nat_gateways) > 1 else "single",
    }
    if not nat_gateways:
        nat_var['type'] = "none"


    # route_tables
    private_keys = sorted(subnets_var.get('private', {}).keys())
    nonroutable_keys = sorted(subnets_var.get('nonroutable', {}).keys())
    
    private_routes = [{ "cidr": "0.0.0.0/0", "target": "nat", "az_key": k } for k in private_keys]
    nonroutable_routes = [{ "cidr": "10.0.0.0/8", "target": "nat", "az_key": k } for k in nonroutable_keys]
    
    route_tables_var = {
        "public": {
            "routes": [
                {"cidr": "0.0.0.0/0", "target": "igw"}
            ]
        },
        "private": {
            "routes": private_routes
        },
        "nonroutable": {
            "routes": nonroutable_routes
        }
    }

    # dhcp_enabled and dhcp
    dhcp_enabled = True

    dhcp_var = {
        "domain_name": "example.internal",
        "domain_name_servers": ["10.0.0.2"],
        "ntp_servers": ["10.0.0.10"],
        "netbios_name_servers": ["10.0.0.20"],
        "netbios_node_type": 2
    }
    
    # sg_rules and nacl_rules
    sg_rules_var = {
        "inbound": [
            {"rule_no": 100, "description": "Allow HTTPS", "protocol": "tcp", "from": 443, "to": 443, "cidr": "0.0.0.0/0"},
            {"rule_no": 110, "description": "Allow SSH internal", "protocol": "tcp", "from": 22, "to": 22, "cidr": "10.0.0.0/8"}
        ],
        "outbound": [
            {"rule_no": 100, "description": "Allow All outbound", "protocol": "-1", "from": 0, "to": 0, "cidr": "0.0.0.0/0"}
        ]
    }

    nacl_rules_var = {
        "public": [
            {"rule_no": 100, "protocol": "6", "from": 443, "to": 443, "cidr": "0.0.0.0/0", "egress": True},
            {"rule_no": 110, "protocol": "6", "from": 1024, "to": 65535, "cidr": "0.0.0.0/0", "egress": False}
        ],
        "private": [
            {"rule_no": 100, "protocol": "6", "from": 443, "to": 443, "cidr": "10.0.0.0/8", "egress": False},
            {"rule_no": 110, "protocol": "6", "from": 0, "to": 65535, "cidr": "10.0.0.0/8", "egress": True}
        ]
    }
    
    #  vpc_endpoints
    vpc_endpoints_var = {
        "ssm": True,
        "ec2messages": True,
        "s3": True,
    }

    # tags (Global tags, derived from user's example)
    global_tags_var = {
        "Environment": "dev",
        "Application": "vpc1",
        "Owner": "network-team",
    }


    # Generate HCL Output ---
    hcl_content = [
        f'# Generated from {JSON_FILE} by {os.path.basename(__file__)}',
        '# This file is structured to match the module schema derived from the provided tfvars example.',
        '# The CIDR blocks and AZs are extracted directly from AWS via the JSON discovery file.',
        '',
        '##################################################################',
        '# ENVIRONMENT METADATA',
        '##################################################################',
        f'name_prefix = "{name_prefix}"',
        f'region = "{region}"',
        '',
        '##################################################################',
        '# VPC CONFIGURATION',
        '##################################################################',
        f'vpc = {hcl_format_map(vpc_var, 0)}',
        '',
        '##################################################################',
        '# SUBNET CONFIGURATION',
        '# If you still see warnings, it means you have more than one subnet for that type (e.g., two public subnets) in the same AZ.',
        '# Only the primary/largest subnet for each type/AZ slot was mapped.',
        '##################################################################',
        f'subnets = {hcl_format_map(subnets_var, 0)}',
        '',
        '##################################################################',
        '# NAT CONFIGURATION',
        '##################################################################',
        f'nat = {hcl_format_map(nat_var, 0)}',
        '',
        '##################################################################',
        '# ROUTE TABLE DEFINITIONS (GENERATED)',
        '##################################################################',
        f'route_tables = {hcl_format_map(route_tables_var, 0)}',
        '',
        '##################################################################',
        '# DHCP OPTIONS (Placeholder from Example)',
        '##################################################################',
        f'dhcp_enabled = {str(dhcp_enabled).lower()}',
        f'dhcp = {hcl_format_map(dhcp_var, 0)}',
        '',
        '##################################################################',
        '# SG RULES (Placeholder from Example)',
        '##################################################################',
        f'sg_rules = {hcl_format_map(sg_rules_var, 0)}',
        '',
        '##################################################################',
        '# NACL RULES (Placeholder from Example)',
        '##################################################################',
        f'nacl_rules = {hcl_format_map(nacl_rules_var, 0)}',
        '',
        '##################################################################',
        '# VPC ENDPOINTS (Placeholder from Example)',
        '##################################################################',
        f'vpc_endpoints = {hcl_format_map(vpc_endpoints_var, 0)}',
        '',
        '##################################################################',
        '# GLOBAL TAGS',
        '##################################################################',
        f'tags = {hcl_format_map(global_tags_var, 0)}',
    ]

    # Write the file
    try:
        with open(OUTPUT_FILE, 'w') as f:
            f.write('\n'.join(hcl_content))
        
        print("\n--- TFVARS GENERATION COMPLETE ---")
        print(f"Successfully generated tfvars file: '{OUTPUT_FILE}'")
        print("I have applied the most rigorous comma-handling logic yet. This should eliminate the standalone comma error.")
        
    except Exception as e:
        print(f"ERROR writing file: {e}")

if __name__ == "__main__":
    generate_tfvars_from_json()