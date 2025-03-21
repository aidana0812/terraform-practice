resource "aws_route_table" "my_rtb" {
  vpc_id = var.vpc_id

  tags = {
    Name = var.rtb_tag
  }
}