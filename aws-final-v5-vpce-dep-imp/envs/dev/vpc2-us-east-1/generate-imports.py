import json
import sys
import os
import re

# Configuration
TF_VARS_FILE = "dev-us-east-1.tfvars"
# Read environment variable to determine if script is being run from inside the module
# Set this to 'true' if running inside the route-tables module directory: 
#   export TF_IMPORT_LOCAL=true
RUN_LOCAL = os.getenv('TF_IMPORT_LOCAL', 'false').lower() == 'true'

# Define the order for importing resources to minimize dependency conflicts in the state file.
IMPORT_ORDER = {
    "aws_vpc": 1,
    "aws_internet_gateway": 2,
    "aws_subnet": 3,
    "aws_eip": 4, # Needed for NAT Gateway
    "aws_nat_gateway": 5,
    "aws_route_table": 6, 
    "aws_network_acl": 7,
    "aws_vpc_endpoint": 8, 
    "aws_route": 9,
    "aws_route_table_association": 10, # Will now be flagged as MANUAL
    "aws_network_acl_association": 11, # Will now be flagged as MANUAL
    # Any other resources (like Security Groups, etc.) would be 100
}

def fix_tf_address_quoting(address):
    """
    Ensures that non-numeric indices in Terraform resource addresses are properly quoted.
    This is primarily for NACL associations (aws_network_acl_association) which use for_each.
    """
    def quote_match(match):
        index_content = match.group(1).strip()
        # Check if the content is already quoted (e.g., ["a"])
        if (index_content.startswith('"') and index_content.endswith('"')):
            return match.group(0) 
        # Check if the content is a number (e.g., [0])
        if index_content.isdigit():
            return f"[{index_content}]"
        # If it's a string index without quotes (e.g., [a]), add quotes
        return f'["{index_content}"]'

    # Apply quoting correction to all bracketed indices
    processed_address = re.sub(r'\[(.*?)\]', quote_match, address)
    return processed_address


def generate_import_script(json_filepath="resources_for_import.json", output_filepath="run_import.sh"):
    """
    Reads the JSON discovery file, sorts resources by dependency, and generates 
    an executable shell script containing all terraform import commands.
    """
    print(f"-> Reading discovery data from: {json_filepath}")
    if RUN_LOCAL:
        print("-> LOCAL IMPORT MODE: Removing 'module.rts.' prefix from addresses.")
    
    try:
        with open(json_filepath, 'r') as f:
            discovered_resources = json.load(f)
    except FileNotFoundError:
        print(f"ERROR: JSON file '{json_filepath}' not found. Please run the discovery script first.")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"ERROR: Could not decode JSON from '{json_filepath}'. Check file integrity.")
        sys.exit(1)

    # 1. Sort the discovered resources based on the defined IMPORT_ORDER
    sorted_resources = sorted(
        discovered_resources,
        key=lambda r: IMPORT_ORDER.get(r['type'], 100)
    )

    # 2. Generate the shell script content
    script_lines = [
        "#!/bin/bash",
        "#",
        "# --- Terraform Import Script ---",
        "# Generated from resources_for_import.json",
        "#",
        "# CRITICAL: Run 'terraform init' in your target directory before executing this script.",
        "# **FINAL FIXES applied based on your HCL:**",
        "# 1. Module name set to 'rts' or 'nacls' as appropriate.",
        "# 2. RTA/NACA FIX: aws_route_table_association and aws_network_acl_association are MANUAL IMPORTS.",
        "# 3. NACL Naming FIX: aws_network_acl.this[...] is mapped to .public or .private.",
        "# 4. RTA Naming FIX: aws_route_table_association map format is converted to explicit HCL names (e.g., .public_assoc_c).",
        "# 5. VPC Endpoint FIX: Uses 'interface' or 'gateway' based on service key.",
        "#",
        f"echo 'Starting layered state import. Local Mode: {RUN_LOCAL}'",
        "",
    ]
    
    import_count = 0
    manual_import_lines = ["\n# --- MANUAL IMPORTS REQUIRED ---"]
    
    # Iterate over sorted resources
    for resource in sorted_resources: 
        aws_id = resource['aws_id']
        tf_address = resource['terraform_address']
        resource_type = resource['type']
        metadata = resource.get('metadata', {})
        name = metadata.get('Name', aws_id)
        
        # --- Pre-Import Fixes ---
        
        # UNIVERSAL FIX 1: Correct the module name to 'rts' (for route tables) or 'nacls' (for NACLs)
        tf_address = tf_address.replace("module.route_tables.", "module.rts.", 1)
        tf_address = tf_address.replace("module.route-tables.", "module.rts.", 1)
        
        # Override for NACLs which are in 'module.nacls'
        if resource_type.startswith("aws_network_acl"):
            tf_address = tf_address.replace("module.rts.", "module.nacls.", 1)
            # Ensure only one module prefix exists
            tf_address = re.sub(r'^(module\.nacls\.)?(module\.nacls\.)', 'module.nacls.', tf_address) 
        
        # --- FIX MISIDENTIFIED RESOURCES ---
        
        # 0. CRITICAL FIX: aws_network_acl.this[...] -> map to .public or .private (Fixes the .this[0] error)
        if resource_type == "aws_network_acl" and re.search(r'\.aws_network_acl\.this\[', tf_address):
            resource_name_lower = name.lower()
            
            hcl_name = None
            if "public" in resource_name_lower:
                hcl_name = "public"
            elif "private" in resource_name_lower:
                hcl_name = "private"
            
            if hcl_name:
                tf_address = re.sub(r'aws_network_acl\.this\[.*?\]$', f'aws_network_acl.{hcl_name}', tf_address)
                tf_address = re.sub(r'^(module\.nacls\.)?aws_network_acl\.', 'module.nacls.aws_network_acl.', tf_address)
                script_lines.append(f"# NOTE: Mapped generic NACL (Name: {name}) to: {tf_address}")
            else:
                script_lines.append(f"# WARNING: Could not map generic NACL '{tf_address}' (Name: {name}) to .public or .private. Skipping for safety.")
                script_lines.append("")
                continue # Skip unmappable generic NACLs

        
        # 1. IGNORE: aws_route_table.main[...] (Does not exist in your route-tables HCL)
        if re.search(r'\.aws_route_table\.main\["(.)"\]$', tf_address):
             script_lines.append(f"# WARNING: Skipping incorrectly discovered resource: {tf_address} (Does not exist in HCL. Likely a naming error)")
             script_lines.append(f"# AWS ID: {aws_id}. If this is a required resource, please identify the correct HCL name.")
             script_lines.append("")
             continue # Skip this resource
        
        # 2. LOCAL MODE CHECK: If run locally (inside module dir), remove module prefix.
        local_prefix = "module.rts."
        if resource_type.startswith("aws_network_acl"):
            local_prefix = "module.nacls."
            
        if RUN_LOCAL:
            if tf_address.startswith(local_prefix):
                tf_address = tf_address.replace(local_prefix, "", 1)
        
        # 3. Override Terraform Address for IGW (Known fix)
        if resource_type == "aws_internet_gateway":
            tf_address = "module.gateways.aws_internet_gateway.igw" 
        
        # 4. CRITICAL FIX: Correct the resource address for subnets (e.g., nonroutable["a"] -> nonroutable_a[0]).
        if resource_type == "aws_subnet":
            match = re.match(r'^(module\.subnets\.aws_subnet\.(public|private|nonroutable))\["(.)"\]$', tf_address)
            if match:
                tier = match.group(2) 
                suffix = match.group(3) 
                tf_address = f"module.subnets.aws_subnet.{tier}_{suffix}[0]"
        
        # 5. CRITICAL FIX: Correct the resource address for EIPs (e.g., public_nat["c"] -> public_nat_c).
        if resource_type == "aws_eip":
            match = re.match(r'^(module\.gateways\.aws_eip\.public_nat)\["(.)"\]$', tf_address)
            if match:
                base_name = match.group(1).split('.')[-1]
                suffix = match.group(2)
                tf_address = f"module.gateways.aws_eip.{base_name}_{suffix}"

        # 6. CRITICAL FIX: Correct the resource address for NAT Gateways (e.g., private_nat["c"] -> private_nat_c).
        if resource_type == "aws_nat_gateway":
            match = re.match(r'^(module\.gateways\.aws_nat_gateway\.(public_nat|private_nat))\["(.)"\]$', tf_address)
            if match:
                resource_base = match.group(2) 
                suffix = match.group(3) 
                tf_address = f"module.gateways.aws_nat_gateway.{resource_base}_{suffix}"
        
        # 7. CRITICAL FIX: Route Table Naming (converting inferred map back to explicit HCL name)
        if resource_type in ["aws_route_table", "aws_route_table_association", "aws_route"]:
            
            # --- Fix RT Names (aws_route_table) ---
            if resource_type == "aws_route_table":
                # Handle Public RT (public["a"] -> public) - Public is a single resource in HCL
                match_public = re.search(r'\.aws_route_table\.public\["(.)"\]$', tf_address)
                if match_public:
                    # Convert indexed public route table to the single resource name
                    tf_address = tf_address[:match_public.start()] + ".aws_route_table.public"
                    
                # Handle AZ-mapped RTs (private/nonroutable -> private_c/nonroutable_c)
                match_az_rt = re.search(r'\.aws_route_table\.(private|nonroutable)\["(.)"\]$', tf_address)
                if match_az_rt:
                    resource_base = match_az_rt.group(1) 
                    suffix = match_az_rt.group(2) 
                    tf_address = tf_address[:match_az_rt.start()] + f".aws_route_table.{resource_base}_{suffix}"

            # --- Fix RTA/NACA Names (Convert map format to explicit names) ---
            elif resource_type in ["aws_route_table_association", "aws_network_acl_association"]:
                 # RTA HCL uses explicit names (public_assoc_a), but discovery yields map-like (public_assoc["a"])
                 match_map = re.search(r'\.(public_assoc|private_assoc|nonroutable_assoc)\[["\']?([abc])["\']?\]$', tf_address)
                 if match_map:
                    resource_base = match_map.group(1) # e.g., 'public_assoc'
                    suffix = match_map.group(2)        # e.g., 'a' or 'c'
                    
                    # Convert map/indexed format to explicit name (public_assoc_c)
                    tf_address = tf_address[:match_map.start()] + f".{resource_base}_{suffix}"
                    script_lines.append(f"# NOTE: Mapped Association (map/indexed format) to explicit HCL name: {tf_address}")
                    
            # --- Fix Route Names (aws_route) ---
            elif resource_type == "aws_route":
                 # Convert inferred route name (e.g., private_routes_a) back to explicit HCL name (private_routes_a)
                 match_az_routes = re.search(r'\.aws_route\.(private_routes|nonroutable_routes)\["(.)"\]$', tf_address)
                 if match_az_routes:
                    resource_base = match_az_routes.group(1) 
                    suffix = match_az_routes.group(2)
                    tf_address = tf_address[:match_az_routes.start()] + f".aws_route.{resource_base}_{suffix}"

        # 8. CRITICAL FIX: VPC Endpoint Naming (Uses your defined 'interface' or 'gateway')
        if resource_type == "aws_vpc_endpoint":
            match = re.match(r'^(module\.vpc_endpoints\.aws_vpc_endpoint)\["(.*?)"\]$', tf_address)
            if match:
                service_key = match.group(2)
                # BASED ON YOUR HCL: S3 is 'gateway', others (ssm, ec2messages) are 'interface'.
                hcl_resource_name = "gateway" if service_key.lower() == "s3" else "interface"
                
                tf_address = f"module.vpc_endpoints.aws_vpc_endpoint.{hcl_resource_name}[\"{service_key}\"]"
                script_lines.append(f"# NOTE: Fixed VPC Endpoint address by adding HCL resource name '{hcl_resource_name}' (bypassing failure): {tf_address}")
                    
        # 9. Ensure generic quoting is correct for any remaining resources (only for_each resources like NACA)
        if resource_type == "aws_network_acl_association":
             tf_address = fix_tf_address_quoting(tf_address)


        # --- MANUAL IMPORT HANDLING (RTA & NACA) ---
        if resource_type in ["aws_route_table_association", "aws_network_acl_association"]:
            import_count += 1
            # Add instruction to the manual list
            manual_import_lines.append(f"# MANUAL IMPORT REQUIRED for {resource_type}: {name}")
            manual_import_lines.append(f"# Terraform Address: '{tf_address}'")
            manual_import_lines.append(f"# AWS Association ID: {aws_id} (INSUFFICIENT)")
            
            # RTA requires SubnetID/RouteTableID
            if resource_type == "aws_route_table_association":
                 manual_import_lines.append(f"### REQUIRED COMMAND ###")
                 manual_import_lines.append(f"# terraform import -var-file={TF_VARS_FILE} '{tf_address}' 'SUBNET_ID/ROUTE_TABLE_ID'")
                 manual_import_lines.append(f"########################\n")
            
            # NACA requires SubnetID/NetworkACLID
            elif resource_type == "aws_network_acl_association":
                 manual_import_lines.append(f"### REQUIRED COMMAND ###")
                 manual_import_lines.append(f"# terraform import -var-file={TF_VARS_FILE} '{tf_address}' 'SUBNET_ID/NETWORK_ACL_ID'")
                 manual_import_lines.append(f"########################\n")
            
            continue # Skip adding the failed import attempt to the main script

        # --- Automatic Import ---
        
        # Add a comment for the current resource
        script_lines.append(f"# Importing {resource_type}: {name} ({aws_id}) to {tf_address}")

        # Conditional Import check
        tf_address_escaped = tf_address.replace('[', '\\[').replace(']', '\\]').replace('"', '\\"')

        script_lines.append(f"if terraform state list | grep -q '^{tf_address_escaped}$'; then")
        script_lines.append(f"  echo '-> SKIP: {tf_address} is already in state. Moving to next resource.'")
        script_lines.append("else")
        
        # Wrap the Terraform address in single quotes (') in the bash command
        command = f"terraform import -input=false -var-file={TF_VARS_FILE} '{tf_address}' {aws_id}"
        
        # Add the command and error check inside the 'else' block
        script_lines.append(f"  {command}")
        script_lines.append(f"  if [ $? -ne 0 ]; then echo \"\n!!! FAILED to import {tf_address} !!!\n\"; exit 1; fi")
        script_lines.append("fi")
        script_lines.append("")
        import_count += 1

    script_lines.extend(manual_import_lines)
    script_lines.append(f"echo '--- SUCCESS! {import_count} resources processed. Please manually run the commands listed in MANUAL IMPORTS. ---'")
    script_lines.append(f"echo 'Run: terraform plan -var-file={TF_VARS_FILE} (to verify state consistency)'")
    
    # 3. Write the script to the output file
    try:
        with open(output_filepath, 'w') as f:
            f.write('\n'.join(script_lines))
        
        # Make the script executable
        os.chmod(output_filepath, 0o755)

        print("\n--- GENERATION COMPLETE ---")
        print(f"Successfully generated executable script: '{output_filepath}'")
        print(f"Total automatic commands generated: {import_count}")
        print("Next step: Run this script inside your target Terraform folder.")

    except Exception as e:
        print(f"ERROR writing file: {e}")

if __name__ == "__main__":
    generate_import_script()