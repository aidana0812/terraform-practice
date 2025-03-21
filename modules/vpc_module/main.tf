resource "aws_vpc" "vpc" { # how we want to name it 
  cidr_block       = var.cidr_block
  tags = {
    Name = var.name
  }
  }

