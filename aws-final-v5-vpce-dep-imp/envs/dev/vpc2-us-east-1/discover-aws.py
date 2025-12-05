import boto3
import json
import re
import sys


TF_ADDRESSES = {
    
    "VPC": "module.vpc.aws_vpc.this",
    "IGW": "module.vpc.aws_internet_gateway.this",
    "SUBNET": "module.subnets.aws_subnet.<TYPE>[\"<AZ_KEY>\"]",
    "EIP": "module.gateways.aws_eip.public_nat[\"<AZ_KEY>\"]",
    "NAT_GATEWAY": "module.gateways.aws_nat_gateway.private_nat[\"<AZ_KEY>\"]",
    "ROUTE_TABLE": "module.route_tables.aws_route_table.<TYPE>[\"<AZ_KEY>\"]", 
    "ROUTE": "module.route_tables.aws_route.<RT_TYPE>[<CIDR>]",
    "NACL": "module.nacls.aws_network_acl.this[0]",
    "NACL_ASSOC": "module.nacls.aws_network_acl_association.<RT_TYPE>_assoc[\"<AZ_KEY>\"]",
    "VPC_ENDPOINT": "module.vpc_endpoints.aws_vpc_endpoint[\"<SERVICE_NAME>\"]",
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
    client = boto3.client('ec2')
    resources_for_import = []
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
        print("ERROR: VPC not found. plz check AWS region/connection.")
        return []

    vpc = vpcs[0]
    vpc_id = vpc['VpcId']
    vpc_name = get_tag_value(vpc.get('Tags', []), 'Name') or vpc_id
    
    print(f"-> Found VPC ID: {vpc_id} (Name: {vpc_name})")
    
   
    resources_for_import.append({
        "type": "aws_vpc",
        "aws_id": vpc_id,
        "terraform_address": TF_ADDRESSES["VPC"],
        "metadata": {"Name": vpc_name, "VpcId": vpc_id}
    })

   
    response = client.describe_internet_gateways(Filters=[{'Name': 'attachment.vpc-id', 'Values': [vpc_id]}])
    if response['InternetGateways']:
        igw_id = response['InternetGateways'][0]['InternetGatewayId']
        resources_for_import.append({
            "type": "aws_internet_gateway",
            "aws_id": igw_id,
            "terraform_address": TF_ADDRESSES["IGW"],
            "metadata": {"VpcId": vpc_id}
        })

   
    response = client.describe_subnets(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    subnets = response.get('Subnets', [])
    
   
    subnet_map = {} 
    
    for subnet in subnets:
        subnet_id = subnet['SubnetId']
        cidr = subnet['CidrBlock']
        az = subnet['AvailabilityZone']
        subnet_name = get_tag_value(subnet.get('Tags', []), 'Name') or f"{vpc_name}-subnet-{az}"
        
   
        subnet_type = "public"
        if subnet_name:
            if "nonroutable" in subnet_name.lower():
                 subnet_type = "nonroutable"
            elif "private" in subnet_name.lower():
                 subnet_type = "private"
        
        az_key = az[-1:]
        
        tf_address = TF_ADDRESSES["SUBNET"].replace("<TYPE>", subnet_type).replace("<AZ_KEY>", az_key)
        
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

    response = client.describe_nat_gateways(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for nat in response.get('NatGateways', []):
        nat_id = nat['NatGatewayId']
        subnet_id = nat['SubnetId']
        az_key = subnet_map.get(subnet_id, {}).get('az_key', 'unknown')
        
        tf_address_nat = TF_ADDRESSES["NAT_GATEWAY"].replace("<AZ_KEY>", az_key)
        resources_for_import.append({
            "type": "aws_nat_gateway",
            "aws_id": nat_id,
            "terraform_address": tf_address_nat,
            "metadata": {"VpcId": vpc_id, "SubnetId": subnet_id, "AzKey": az_key}
        })
        
      #EIP
        if nat.get('NatGatewayAddresses'):
            nat_address = nat['NatGatewayAddresses'][0]
            if nat_address.get('AllocationId'):
                eip_alloc_id = nat_address['AllocationId']

                tf_address_eip = TF_ADDRESSES["EIP"].replace("<AZ_KEY>", az_key)
                resources_for_import.append({
                    "type": "aws_eip",
                    "aws_id": eip_alloc_id,
                    "terraform_address": tf_address_eip,
                    "metadata": {"AzKey": az_key}
                })
            else:
                print(f"Warning: NAT Gateway {nat_id} found 'AllocationId' missing(State: {nat.get('State', 'unknown')}). Skipping")

    # ROUTE TABLES, ROUTES, and ASSOCIATIONS 

    response = client.describe_route_tables(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for rt in response.get('RouteTables', []):
        rt_id = rt['RouteTableId']
        rt_name = get_tag_value(rt.get('Tags', []), 'Name') or rt_id
        
        associations = rt.get('Associations', [])
        rt_type = "main"
        rt_az_key = 'a'
        subnet_id_for_type = None

        for assoc in associations:
            if assoc.get('SubnetId'):
                subnet_id_for_type = assoc['SubnetId']
                break
        
        if subnet_id_for_type and subnet_id_for_type in subnet_map:
            rt_type = subnet_map[subnet_id_for_type]['type']
            rt_az_key = subnet_map[subnet_id_for_type]['az_key']
        tf_address_rt = TF_ADDRESSES["ROUTE_TABLE"].replace("<TYPE>", rt_type).replace("<AZ_KEY>", rt_az_key)
            
        resources_for_import.append({
            "type": "aws_route_table",
            "aws_id": rt_id,
            "terraform_address": tf_address_rt,
            "metadata": {"Name": rt_name, "VpcId": vpc_id, "RtType": rt_type, "RtAzKey": rt_az_key}
        })
        
        #  ROUTE TABLE ASSOCIATIONS
        for assoc in associations:
            subnet_id = assoc.get('SubnetId')
            if subnet_id and subnet_id in subnet_map:
                az_key = subnet_map[subnet_id]['az_key']
                subnet_type = subnet_map[subnet_id]['type']
                tf_address_assoc = TF_ADDRESSES["RT_ASSOC"].replace("<TYPE>", subnet_type).replace("<AZ_KEY>", az_key)

                resources_for_import.append({
                    "type": "aws_route_table_association",
                    "aws_id": assoc['RouteTableAssociationId'],
                    "terraform_address": tf_address_assoc,
                    "metadata": {"SubnetId": subnet_id, "RouteTableId": rt_id, "SubnetType": subnet_type}
                })


    # NETWORK ACLS
    response = client.describe_network_acls(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    if response.get('NetworkAcls'):
        nacl_id = response['NetworkAcls'][0]['NetworkAclId']
        
        resources_for_import.append({
            "type": "aws_network_acl",
            "aws_id": nacl_id,
            "terraform_address": TF_ADDRESSES["NACL"],
            "metadata": {"VpcId": vpc_id}
        })
        
        # Network ACL Associations
        for nacl in response.get('NetworkAcls', []):
            for assoc in nacl.get('Associations', []):
                subnet_id = assoc.get('SubnetId')
                if subnet_id and subnet_id in subnet_map:
                    az_key = subnet_map[subnet_id]['az_key']
                    subnet_type = subnet_map[subnet_id]['type']
                    tf_address_nacl_assoc = TF_ADDRESSES["NACL_ASSOC"].replace("<RT_TYPE>", subnet_type).replace("<AZ_KEY>", az_key)

                    resources_for_import.append({
                        "type": "aws_network_acl_association",
                        "aws_id": assoc['NetworkAclAssociationId'],
                        "terraform_address": tf_address_nacl_assoc,
                        "metadata": {"SubnetId": subnet_id, "NaclId": nacl_id, "SubnetType": subnet_type}
                    })

    # VPC Endpoint
    response = client.describe_vpc_endpoints(Filters=[{'Name': 'vpc-id', 'Values': [vpc_id]}])
    for ep in response.get('VpcEndpoints', []):
        ep_id = ep['VpcEndpointId']
        service_name = ep['ServiceName'].split('.')[-1].replace('-', '_')
        
        
        tf_address_ep = TF_ADDRESSES["VPC_ENDPOINT"].replace("<SERVICE_NAME>", service_name)
        
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
        
    try:
        boto3.client('ec2').describe_regions()
    except Exception as e:
        print("--- AWS AUTHENTICATION ERROR ---")
        print(f"Details: {e}")
        sys.exit(1)


    discovered_resources = discover_vpc_resources(vpc_identifier)
    
    if discovered_resources:
        with open("resources_for_import.json", "w") as f:
            json.dump(discovered_resources, f, indent=4)
        
        print("\n--- DISCOVERY COMPLETE ---")
        print(f"Successfully discovered {len(discovered_resources)} resources.")
        print("The file 'resources_for_import.json' has been updated.")
    else:
        print("\n--- DISCOVERY FAILED ---")
        print("No resources were discovered. Please check the VPC ID/Name and AWS connectivity.")