###############################################
# OUTPUTS FOR VPC ENDPOINTS (IMPORT-FRIENDLY)
###############################################

# Map of interface VPC endpoints (SSM, EC2 Messages, SSM Messages)
output "interface_endpoint_ids" {
  description = "Map of interface VPC endpoint IDs keyed by internal service name (ssm, ec2messages, ssm_messages)."
  value       = { for k, v in aws_vpc_endpoint.interface : k => v.id }
}

# Map of gateway VPC endpoints (S3)
output "gateway_endpoint_ids" {
  description = "Map of gateway VPC endpoint IDs keyed by internal service name (s3)."
  value       = { for k, v in aws_vpc_endpoint.gateway : k => v.id }
}

# Combined map of all created endpoint IDs
output "all_endpoint_ids" {
  description = "Combined map of all VPC endpoint IDs (interface + gateway)."
  value       = merge(
    { for k, v in aws_vpc_endpoint.interface : k => v.id },
    { for k, v in aws_vpc_endpoint.gateway : k => v.id }
  )
}