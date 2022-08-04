resource "aws_key_pair" "node_group_keypair" {
  key_name   = "node_group_keypair"
  public_key = file("node_group_keypair.pub")
}

resource "aws_launch_template" "launch_template" {
  name="launch-template-for-node-group"
  image_id = "ami-04ff9e9b51c1f62ca"
  key_name = aws_key_pair.node_group_keypair.key_name
}