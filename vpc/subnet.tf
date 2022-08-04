resource "aws_subnet" "public_subnet" {
  for_each          = toset(var.cidr_block_public_subnet)
  vpc_id            = aws_vpc.eks_vpc.id
  cidr_block        = each.value
  availability_zone = data.aws_availability_zones.az.names[index(var.cidr_block_public_subnet, each.value)]
  map_public_ip_on_launch = true

  tags = {
    Name = "EKS public subnet ${index(var.cidr_block_public_subnet, each.value) + 1}"
  }
}

# resource "aws_subnet" "private_subnet" {
#   for_each          = toset(var.cidr_block_private_subnet)
#   vpc_id            = aws_vpc.eks_vpc.id
#   cidr_block        = each.value
#   availability_zone = data.aws_availability_zones.az.names[index(var.cidr_block_private_subnet, each.value)]

#   tags = {
#     Name = "EKS private subnet ${index(var.cidr_block_private_subnet, each.value) + 1}"
#   }
# }