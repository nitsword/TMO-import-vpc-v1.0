###########################################
# Subnets module - Public Tier (Fixed Addresses)
###########################################

resource "aws_subnet" "public_a" {
  # Create this subnet only if configuration for key "a" exists in var.subnets.public
  count = try(var.subnets.public["a"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.public["a"].cidr, "")
  availability_zone = try(var.subnets.public["a"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-public-a" },
    var.tags
  )
}

resource "aws_subnet" "public_b" {
  count = try(var.subnets.public["b"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.public["b"].cidr, "")
  availability_zone = try(var.subnets.public["b"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-public-b" },
    var.tags
  )
}

resource "aws_subnet" "public_c" {
  count = try(var.subnets.public["c"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.public["c"].cidr, "")
  availability_zone = try(var.subnets.public["c"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-public-c" },
    var.tags
  )
}

###########################################
# Subnets module - Private Tier (Fixed Addresses)
###########################################

resource "aws_subnet" "private_a" {
  count = try(var.subnets.private["a"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.private["a"].cidr, "")
  availability_zone = try(var.subnets.private["a"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-private-a" },
    var.tags
  )
}

resource "aws_subnet" "private_b" {
  count = try(var.subnets.private["b"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.private["b"].cidr, "")
  availability_zone = try(var.subnets.private["b"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-private-b" },
    var.tags
  )
}

resource "aws_subnet" "private_c" {
  count = try(var.subnets.private["c"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.private["c"].cidr, "")
  availability_zone = try(var.subnets.private["c"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-private-c" },
    var.tags
  )
}

###########################################
# Subnets module - Nonroutable Tier (Fixed Addresses)
###########################################

resource "aws_subnet" "nonroutable_a" {
  count = try(var.subnets.nonroutable["a"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.nonroutable["a"].cidr, "")
  availability_zone = try(var.subnets.nonroutable["a"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-nonroutable-a" },
    var.tags
  )
}

resource "aws_subnet" "nonroutable_b" {
  count = try(var.subnets.nonroutable["b"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.nonroutable["b"].cidr, "")
  availability_zone = try(var.subnets.nonroutable["b"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-nonroutable-b" },
    var.tags
  )
}

resource "aws_subnet" "nonroutable_c" {
  count = try(var.subnets.nonroutable["c"], null) != null ? 1 : 0

  vpc_id            = var.vpc_id
  cidr_block        = try(var.subnets.nonroutable["c"].cidr, "")
  availability_zone = try(var.subnets.nonroutable["c"].az, "")

  tags = merge(
    { Name = "${var.name_prefix}-nonroutable-c" },
    var.tags
  )
}