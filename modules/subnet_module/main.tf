resource "aws_subnet" "subnet" {
  vpc_id     = var.vpc_id
  cidr_block = var.cidr_block
  map_public_ip_on_launch = var.map_public_ip_on_launch 
  availability_zone = var.availability_zone

  tags = {
    Name = var.subnet_tag
  }
}