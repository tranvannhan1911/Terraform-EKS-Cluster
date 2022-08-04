# resource "aws_eip" "eip_nat_gw" {
# }

# resource "aws_nat_gateway" "nat_gw" {
#   subnet_id     = values(aws_subnet.public_subnet)[0].id
#   allocation_id = aws_eip.eip_nat_gw.id

#   tags = {
#     Name = "NAT Gateway"
#   }
# }