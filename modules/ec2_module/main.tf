resource "aws_instance" "instance" {
  ami = var.ami
  instance_type = var.instance_type
  vpc_security_group_ids = [var.vpc_security_group_ids]
  user_data = var.user_data
  subnet_id = var.subnet_id
  key_name = var.key_name
  tags = {
    Name = var.tag
  }
}