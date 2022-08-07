resource "aws_key_pair" "node_group_keypair" {
  key_name   = "node_group_keypair"
  public_key = file("node_group_keypair.pub")
}

# resource "aws_security_group" "allow_ssh" {
#   name        = "allow-ssh"
#   description = "Allow SSH inbound traffic"
#   vpc_id      = module.vpc.vpc.id
# }

# resource "aws_security_group_rule" "rule_allow_ssh" {
#   type              = "ingress"
#   from_port         = 22
#   to_port           = 22
#   protocol          = "tcp"
#   cidr_blocks       = ["0.0.0.0/0"]
#   security_group_id = aws_security_group.allow_ssh.id
# }

# resource "aws_launch_template" "launch_template" {
#   name="launch-template-for-node-group"
#   image_id = "ami-04ff9e9b51c1f62ca"
#   key_name = aws_key_pair.node_group_keypair.key_name
#   vpc_security_group_ids = [aws_security_group.allow_ssh.id]
# }