resource "aws_db_subnet_group" "db_subnet_gr" {
  name = var.name
  subnet_ids = var.subnet_ids
  tags = {
    Name = var.tag
  }
}