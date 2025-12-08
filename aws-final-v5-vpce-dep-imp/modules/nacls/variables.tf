variable "vpc_id" {
  description = "The VPC ID to associate NACLs with."
  type        = string
}

variable "public_subnet_ids_map" {
  description = "A map of public subnet IDs (keys are dynamic names/zones)."
  type        = map(string)
}

variable "private_subnet_ids_map" {
  description = "A map of private subnet IDs (keys are dynamic names/zones)."
  type        = map(string)
}

variable "nonroutable_subnet_ids_map" {
  description = "A map of non-routable subnet IDs (keys are dynamic names/zones)."
  type        = map(string)
}

# --- NEW STATIC KEY VARIABLES ---
variable "public_subnet_keys" {
  description = "A set of static keys (e.g., [\"a\", \"b\"]) corresponding to the public_subnet_ids_map"
  type        = set(string)
}

variable "private_subnet_keys" {
  description = "A set of static keys (e.g., [\"a\", \"b\"]) corresponding to the private_subnet_ids_map"
  type        = set(string)
}

variable "nonroutable_subnet_keys" {
  description = "A set of static keys (e.g., [\"a\", \"b\"]) corresponding to the nonroutable_subnet_ids_map"
  type        = set(string)
}
# --------------------------------

variable "nacl_rules" {
  description = "Map containing ingress and egress rules for public and private NACLs."
  type        = any
  default     = {}
}

variable "name_prefix" {
  description = "The prefix to apply to all resources created."
  type        = string
}

variable "tags" {
  description = "A map of tags to apply to all resources."
  type        = map(string)
  default     = {}
}
