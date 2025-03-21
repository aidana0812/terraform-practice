resource "aws_internet_gateway" "igw" {
    vpc_id = var.vpc_id #how you name vpc_is in output in vpc module 
    tags = {
      Name = var.ig_tag
    }
}