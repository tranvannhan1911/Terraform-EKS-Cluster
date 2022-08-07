resource "aws_vpc" "eks_vpc" {
  cidr_block = var.cidr_block

  tags = {
    Name = "EKS VPC"
  }
}

output "vpc" {
  value = aws_vpc.eks_vpc
}

output "public_subnets" {
  value = aws_subnet.public_subnet
}

output "private_subnets" {
  value = aws_subnet.private_subnet
}