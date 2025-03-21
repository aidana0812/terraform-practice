#Create Elastic IP fo NAT Gateway 
resource "aws_eip" "eip" {
  domain = "vpc" 

  tags = {
    Name = var.eip_tag
  }
}

#create NAT gateway 
resource "aws_nat_gateway" "nat" {
  subnet_id     = var.subnet_id
  allocation_id = aws_eip.eip.id

  tags = {
    Name = var.nat_tag 
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_eip.eip]
  #can not reference to other modules 
}