module "vpc" {
  source = "./vpc"

  region = var.region
  cidr_block = var.cidr_block
  cidr_block_public_subnet = var.cidr_block_public_subnet
  cluster_name = var.cluster_name
}

resource "aws_eks_cluster" "cluster" {
  name     = "hiitfigure"
  role_arn = aws_iam_role.iam_role.arn

  vpc_config {
    subnet_ids = [for subnet in module.vpc.public_subnets: subnet.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam-role-AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.iam-role-AmazonEKSVPCResourceController,
  ]
}

resource "aws_eks_node_group" "node_group" {
  cluster_name    = aws_eks_cluster.cluster.name
  node_group_name = "node-group"
  node_role_arn   = aws_iam_role.iam_role_node_group.arn
  subnet_ids      = [for subnet in module.vpc.public_subnets: subnet.id]

  instance_types = ["t2.micro"]

  # launch_template {
  #   id = aws_launch_template.launch_template.id
  #   version = aws_launch_template.launch_template.latest_version
  # }

  remote_access {
    ec2_ssh_key = aws_key_pair.node_group_keypair.key_name
  }

  scaling_config {
    desired_size = 3
    max_size     = 3
    min_size     = 1
  }

  update_config {
    max_unavailable = 2
  }

  depends_on = [
    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.iam_role_node_group-AmazonEC2ContainerRegistryReadOnly,
  ]
}

output "endpoint" {
  value = aws_eks_cluster.cluster.endpoint
}