resource "aws_lb_target_group" "my_target_group" {
  name     = var.name
  port     = var.port
  protocol = var.protocol
  vpc_id   = var.vpc_id
  tags = {
    Name = var.tg_tag
  }
}

