resource "aws_route_table" "rtb" {
  vpc_id = var.vpc_id

  route {
    cidr_block = "0.0.0.0/0"

    # Only use gateway_id if it's provided
    gateway_id = var.gateway_id != null ? var.gateway_id : null

    # Only use nat_gateway_id if it's provided
    nat_gateway_id = var.nat_gateway_id != null ? var.nat_gateway_id : null
  }

  tags = {
    Name = "${var.gateway_id == null ? "private" : "public"}_rtb"
  }
}


resource "aws_route_table_association" "assoc" {
  count = length(var.subnets)
  subnet_id = var.subnets[count.index]
  route_table_id = aws_route_table.rtb.id

}