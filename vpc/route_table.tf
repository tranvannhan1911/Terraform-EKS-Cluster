# route table for public subnets
resource "aws_route_table" "route_table_public_subnet" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name = "Route table public subnet"
  }
}

resource "aws_route" "route_public_subnet" {
  route_table_id            = aws_route_table.route_table_public_subnet.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "route_table_public_subnet_association" {
  for_each = aws_subnet.public_subnet
  subnet_id      = each.value.id
  route_table_id = aws_route_table.route_table_public_subnet.id
}

# route table for private subnets
# resource "aws_route_table" "route_table_private_subnet" {
#   vpc_id = aws_vpc.eks_vpc.id

#   tags = {
#     Name = "Route table private subnet"
#   }
# }

# resource "aws_route" "route_private_subnet" {
#   route_table_id            = aws_route_table.route_table_private_subnet.id
#   destination_cidr_block    = "0.0.0.0/0"
#   nat_gateway_id = aws_nat_gateway.nat_gw.id
# }

# resource "aws_route_table_association" "route_table_private_subnet_association" {
#   for_each = aws_subnet.private_subnet
#   subnet_id      = each.value.id
#   route_table_id = aws_route_table.route_table_private_subnet.id
# }
