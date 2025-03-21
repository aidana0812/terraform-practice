resource "aws_lb" "my_lb" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = var.load_balancer_type
  security_groups    = var.security_groups
  subnets            = var.subnets
  enable_deletion_protection = var.enable_deletion_protection

  tags = {
    Name = var.tag_lb
  }
}

resource "aws_lb_listener" "lb_listener" {
  load_balancer_arn = var.load_balancer_arn # Attach to the Load Balancer
  port             = 80                 # Listen on port 80 (HTTP)
  protocol         = "HTTP"             

  default_action {
    type             = "forward"
    target_group_arn = var.target_group_arn
  }
}
