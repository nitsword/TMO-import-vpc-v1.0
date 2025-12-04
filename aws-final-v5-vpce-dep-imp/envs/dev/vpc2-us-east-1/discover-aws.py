import boto3
import json
import re
import sys

# --- Configuration (Adjust HCL Addresses Here) ---
HCL_ADDRESSES = {
    # HCL addresses for single resources (no map/list index)
    "VPC": "module.vpc.aws_vpc.this",
    "IGW": "module.vpc.aws_internet_gateway.this",
    
    # Using double-quoted map keys for safer shell execution
    "SUBNET": "module.subnets.aws_subnet.<TYPE>[\"<AZ_KEY>\"]",
    
    "EIP": "module.gateways.aws_eip.public_nat[\"<AZ_KEY>\"]",
    "NAT_GATEWAY": "module.gateways.aws_nat_gateway.private_nat[\"<AZ_KEY>\"]",
    
    # Generic patterns for Route Tables
    "ROUTE_TABLE": "module.route_tables.aws_route_table.<TYPE>[\"<AZ_KEY>\"]", 
    "ROUTE": "module.route_tables.aws_route.<RT_TYPE>[<CIDR>]",
    
    "NACL": "module.nacls.aws_network_acl.this[0]",
    "NACL_ASSOC": "module.nacls.aws_network_acl_association.<RT_TYPE>_assoc[\"<AZ_KEY>\"]",
    
    # FIX: Using double quotes for the map key: ["<SERVICE_NAME>"]
    "VPC_ENDPOINT": "module.vpc_endpoints.aws_vpc_endpoint[\"<SERVICE_NAME>\"]",
    
    # Generic pattern for Route Table Associations
    "RT_ASSOC": "module.route_tables.aws_route_table_association.<TYPE>_assoc[\"<AZ_KEY>\"]",
}
# -----------------------------------------------

def get_tag_value(tags, key):
    """Helper function to extract tag value."""
    for tag in tags:
        if tag.get('Key') == key:
            return tag.get('Value')
    return None

def discover_vpc_resources(vpc_identifier):
    """
    Discovers all VPC-related resources based on the VPC ID or the VPC Name tag.
    The function intelligently determines the input type.
    """
    client = boto3.client('ec2')
    resources_for_import = []
    
    # 1. Determine if the identifier is an ID or a Name tag value and set up filters
    is_vpc_id = vpc_identifier.lower().startswith('vpc-')
    
    print(f"-> Searching for VPC using identifier: {vpc_identifier} (Type: {'ID' if is_vpc_id else 'Name Tag'})")
    
    try:
        if is_vpc_id:
            response = client.describe_vpcs(VpcIds=[vpc_identifier])
        else:
            response = client.describe_vpcs(
                Filters=[{'Name': 'tag:Name', 'Values': [vpc_identifier]}]
            )
        
        vpcs = response.get('Vpcs', [])
    except Exception as e:
        print(f"Error during VPC search: {e}")
        return []

    if not vpcs:
        print("ERROR: VPC not found. Check the identifier or AWS region/connectivity.")
        return []

    vpc = vpcs[0]
    vpc_id = vpc['VpcId']
    
    # Get the VPC Name tag for metadata and downstream naming, using the ID as fallback
    vpc_name = get_tag_value(vpc.get('Tags', []), 'Name') or vpc_id
    
    print(f"-> Found VPC ID: {vpc_id} (Name: {vpc_name}). Discovering dependencies...")
    
    # 1.1 ADD VPC
    resources_for_import.append({
        "type": "aws_vpc",
        "aws_id": vpc_id,
        "terraform_address": HCL_ADDRESSES["VPC"],
        "metadata": {"Name": vpc_name, "VpcId": vpc_id}
    })

    # 1.2 ADD IGW (Assuming one per VPC)
    response = client.describe_internet_gateways(Filters=[{'Name': 'attachment.vpc-id', 'Values': [vpc_id]}])
    if response['InternetGateways']:
        igw_id = response['InternetGateways'][0]['InternetGatewayId']
        resources_for_import.append({
            "type": "aws_internet_gateway",
            "aws_id": igw_id,
            "terraform_address": HCL_ADDRESSES["IGW"],
            "metadata": {"VpcId": vpc_id}
        })

    # --- 2. FIND SUBNETS ---
    response = client.describe_subnets(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    subnets = response.get('Subnets', [])
    
    # Store subnet info to resolve dependencies later (especially type and az_key)
    subnet_map = {} 
    
    for subnet in subnets:
        subnet_id = subnet['SubnetId']
        cidr = subnet['CidrBlock']
        az = subnet['AvailabilityZone']
        subnet_name = get_tag_value(subnet.get('Tags', []), 'Name') or f"{vpc_name}-subnet-{az}"
        
        # Derive subnet type (public, private, nonroutable) and AZ key
        subnet_type = "public"
        if subnet_name:
            if "nonroutable" in subnet_name.lower():
                 subnet_type = "nonroutable"
            elif "private" in subnet_name.lower():
                 subnet_type = "private"
        
        az_key = az[-1:] # 'a', 'b', 'c', etc.
        
        tf_address = HCL_ADDRESSES["SUBNET"].replace("<TYPE>", subnet_type).replace("<AZ_KEY>", az_key)
        
        # Add to import list
        resources_for_import.append({
            "type": "aws_subnet",
            "aws_id": subnet_id,
            "terraform_address": tf_address, 
            "metadata": {
                "Name": subnet_name,
                "AvailabilityZone": az,
                "Type": subnet_type,
                "CidrBlock": cidr
            }
        })
        
        subnet_map[subnet_id] = {'az_key': az_key, 'type': subnet_type}


    # --- 3. FIND NAT GATEWAYS and EIPs ---
    response = client.describe_nat_gateways(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for nat in response.get('NatGateways', []):
        nat_id = nat['NatGatewayId']
        subnet_id = nat['SubnetId']
        az_key = subnet_map.get(subnet_id, {}).get('az_key', 'unknown')
        
        # Add NAT Gateway
        tf_address_nat = HCL_ADDRESSES["NAT_GATEWAY"].replace("<AZ_KEY>", az_key)
        resources_for_import.append({
            "type": "aws_nat_gateway",
            "aws_id": nat_id,
            "terraform_address": tf_address_nat,
            "metadata": {"VpcId": vpc_id, "SubnetId": subnet_id, "AzKey": az_key}
        })
        
        # Find associated EIP
        if nat.get('NatGatewayAddresses'):
            nat_address = nat['NatGatewayAddresses'][0]
            # Use .get() to safely check for AllocationId, which prevents the KeyError
            if nat_address.get('AllocationId'):
                eip_alloc_id = nat_address['AllocationId']

                tf_address_eip = HCL_ADDRESSES["EIP"].replace("<AZ_KEY>", az_key)
                resources_for_import.append({
                    "type": "aws_eip",
                    "aws_id": eip_alloc_id,
                    "terraform_address": tf_address_eip,
                    "metadata": {"AzKey": az_key}
                })
            else:
                print(f"Warning: NAT Gateway {nat_id} found but 'AllocationId' is missing from its address (State: {nat.get('State', 'unknown')}). Skipping EIP import for this NAT.")

    # --- 4. FIND ROUTE TABLES, ROUTES, and ASSOCIATIONS ---
    response = client.describe_route_tables(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for rt in response.get('RouteTables', []):
        rt_id = rt['RouteTableId']
        rt_name = get_tag_value(rt.get('Tags', []), 'Name') or rt_id
        
        # Store information about associations to determine the Route Table's type and AZ
        associations = rt.get('Associations', [])
        
        # Determine RT type and AZ key based on its associated subnet. 
        # This is the most reliable way to map it to the HCL module structure.
        rt_type = "main" # Fallback
        rt_az_key = 'a'
        subnet_id_for_type = None

        for assoc in associations:
            if assoc.get('SubnetId'):
                subnet_id_for_type = assoc['SubnetId']
                break
        
        if subnet_id_for_type and subnet_id_for_type in subnet_map:
            rt_type = subnet_map[subnet_id_for_type]['type']
            rt_az_key = subnet_map[subnet_id_for_type]['az_key']
        
        # 4.1 ADD ROUTE TABLE
        # Use the derived type (public, private, nonroutable) and AZ key
        tf_address_rt = HCL_ADDRESSES["ROUTE_TABLE"].replace("<TYPE>", rt_type).replace("<AZ_KEY>", rt_az_key)
            
        resources_for_import.append({
            "type": "aws_route_table",
            "aws_id": rt_id,
            "terraform_address": tf_address_rt,
            "metadata": {"Name": rt_name, "VpcId": vpc_id, "RtType": rt_type, "RtAzKey": rt_az_key}
        })
        
        # 4.2 ADD ROUTE TABLE ASSOCIATIONS
        for assoc in associations:
            subnet_id = assoc.get('SubnetId')
            if subnet_id and subnet_id in subnet_map:
                az_key = subnet_map[subnet_id]['az_key']
                subnet_type = subnet_map[subnet_id]['type']
                
                # Use the correct association address pattern based on subnet type
                tf_address_assoc = HCL_ADDRESSES["RT_ASSOC"].replace("<TYPE>", subnet_type).replace("<AZ_KEY>", az_key)

                resources_for_import.append({
                    "type": "aws_route_table_association",
                    "aws_id": assoc['RouteTableAssociationId'],
                    "terraform_address": tf_address_assoc,
                    "metadata": {"SubnetId": subnet_id, "RouteTableId": rt_id, "SubnetType": subnet_type}
                })


    # --- 5. FIND NETWORK ACLS and Associations ---
    response = client.describe_network_acls(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    if response.get('NetworkAcls'):
        # Assuming one main NACL is managed by the HCL
        nacl_id = response['NetworkAcls'][0]['NetworkAclId']
        
        resources_for_import.append({
            "type": "aws_network_acl",
            "aws_id": nacl_id,
            "terraform_address": HCL_ADDRESSES["NACL"],
            "metadata": {"VpcId": vpc_id}
        })
        
        # Network ACL Associations
        for nacl in response.get('NetworkAcls', []):
            for assoc in nacl.get('Associations', []):
                subnet_id = assoc.get('SubnetId')
                if subnet_id and subnet_id in subnet_map:
                    az_key = subnet_map[subnet_id]['az_key']
                    subnet_type = subnet_map[subnet_id]['type']
                    
                    # Uses subnet type and AZ key in the association address
                    tf_address_nacl_assoc = HCL_ADDRESSES["NACL_ASSOC"].replace("<RT_TYPE>", subnet_type).replace("<AZ_KEY>", az_key)

                    resources_for_import.append({
                        "type": "aws_network_acl_association",
                        "aws_id": assoc['NetworkAclAssociationId'],
                        "terraform_address": tf_address_nacl_assoc,
                        "metadata": {"SubnetId": subnet_id, "NaclId": nacl_id, "SubnetType": subnet_type}
                    })

    # --- 6. FIND VPC Endpoints ---
    response = client.describe_vpc_endpoints(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for ep in response.get('VpcEndpoints', []):
        ep_id = ep['VpcEndpointId']
        service_name = ep['ServiceName'].split('.')[-1].replace('-', '_') # Example: s3
        
        # The service name is correctly placed inside the double quotes for the map key.
        tf_address_ep = HCL_ADDRESSES["VPC_ENDPOINT"].replace("<SERVICE_NAME>", service_name)
        
        resources_for_import.append({
            "type": "aws_vpc_endpoint",
            "aws_id": ep_id,
            "terraform_address": tf_address_ep,
            "metadata": {"ServiceName": ep['ServiceName'], "VpcId": vpc_id}
        })
        
    return resources_for_import

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python vpc_discoverer.py <VPC_ID_OR_NAME_TAG>")
        print("Example (Using ID): python vpc_discoverer.py vpc-054415081e04329ba")
        print("Example (Using Name Tag): python vpc_discoverer.py dev-us-east-1-vpc1")
        sys.exit(1)
        
    vpc_identifier = sys.argv[1]
        
    # Check for Boto3 profile setup (optional, but good practice)
    try:
        boto3.client('ec2').describe_regions()
    except Exception as e:
        print("--- AWS AUTHENTICATION ERROR ---")
        print("Make sure you have Boto3 installed (`pip install boto3`) and your AWS credentials/profile are configured.")
        print(f"Details: {e}")
        sys.exit(1)


    discovered_resources = discover_vpc_resources(vpc_identifier)
    
    if discovered_resources:
        # Save the result to JSON file
        with open("resources_for_import.json", "w") as f:
            json.dump(discovered_resources, f, indent=4)
        
        print("\n--- DISCOVERY COMPLETE ---")
        print(f"Successfully discovered {len(discovered_resources)} resources.")
        print("The file 'resources_for_import.json' has been updated.")
        print("You can now begin the layered import process.")
    else:
        print("\n--- DISCOVERY FAILED ---")
        print("No resources were discovered. Please check the VPC ID/Name and AWS connectivity.")