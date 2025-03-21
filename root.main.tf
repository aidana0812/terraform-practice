#create vpc 
module "dev_vpc" {
  #name can be anything/how we want to name (for terraform) 
  source     = "./modules/vpc_module"
  cidr_block = "10.0.0.0/16"
  name       = "my_vpc" #name for aws 
}
##############################################################################################################
#create subnet
module "public_subnet1" {
  source = "./modules/subnet_module"

  vpc_id = module.dev_vpc.aws_vpc
  #refering to module above where created vpc,then how you named output in the module for vpc

  cidr_block              = "10.0.0.0/18"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  subnet_tag              = "piblic_1a"
}

module "public_subnet2" {
  source = "./modules/subnet_module"

  vpc_id = module.dev_vpc.aws_vpc
  #refering to module above where created vpc,then how you named output in the module for vpc

  cidr_block              = "10.0.128.0/18"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1b"
  subnet_tag              = "piblic_2a"
}

module "private_subnet1" {
  source = "./modules/subnet_module"

  vpc_id = module.dev_vpc.aws_vpc
  #refering to module above where created vpc,then how you named output in the module for vpc

  cidr_block              = "10.0.64.0/18"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1c"
  subnet_tag              = "private_1b"
}

module "private_subnet2" {
  source = "./modules/subnet_module"

  vpc_id = module.dev_vpc.aws_vpc
  #refering to module above where created vpc,then how you named output in the module for vpc

  cidr_block              = "10.0.192.0/18"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1d"
  subnet_tag              = "private_2b"
}

##############################################################################################################

#create IGW 
module "igw" {
  source = "./modules/ig_module"
  vpc_id = module.dev_vpc.aws_vpc
  #first - reference to the module created above for vpc; second - name of output for vpc in vpc module 
  ig_tag = "IGW"
}

##############################################################################################################

#create NAT gateway 
module "nat" {
  source    = "./modules/nat_module"
  vpc_id    = module.dev_vpc.aws_vpc
  eip_tag   = "my_eip"
  subnet_id = module.public_subnet1.id
  nat_tag   = "my_nat"

}
##############################################################################################################
#create route table 
module "rtb" {
  source  = "./modules/rtb_module"
  vpc_id  = module.dev_vpc.aws_vpc
  rtb_tag = "my_rtb"
}
#create aws_route 
# creates a route inside route table 
#this route sends network traffic to Internet Gateway
# it will make public subnet to work 
#without this, instances will not be able to communicate 
# enables public internet access for subnet
resource "aws_route" "aws_route" {
  route_table_id         = module.rtb.rtb_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = module.igw.idw_id
}


# now we need to include what subnets should be in route table in order to have route from internet 
resource "aws_route_table_association" "public_rtb_to_public1a_assoc" {
  subnet_id      = module.public_subnet1.id
  route_table_id = module.rtb.rtb_id
}

resource "aws_route_table_association" "public_rtb_to_public2a_assoc" {
  subnet_id      = module.public_subnet2.id
  route_table_id = module.rtb.rtb_id
}


#CREATE PRIVATE ROUTE TABLE 
#create route table 
module "rtb_private" {
  source  = "./modules/rtb_module"
  vpc_id  = module.dev_vpc.aws_vpc
  rtb_tag = "my_private_rtb"
}

#create aws_route 
resource "aws_route" "aws_route_private" {
  route_table_id         = module.rtb_private.rtb_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat.nat_id
}


# now we need to include what subnets should be in route table in order to have route from internet 
resource "aws_route_table_association" "private_rtb_to_private1a_assoc" {
  subnet_id      = module.private_subnet1.id
  route_table_id = module.rtb_private.rtb_id
}

resource "aws_route_table_association" "private_rtb_to_private2a_assoc" {
  subnet_id      = module.private_subnet2.id
  route_table_id = module.rtb_private.rtb_id
}

##############################################################################################################
#create security group 
module "sgr" {
  source      = "./modules/sgr_module"
  vpc_id      = module.dev_vpc.aws_vpc
  name        = "my_sgr"
  description = "EC2 security group"
}

#create security group 
resource "aws_security_group_rule" "allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr.sgr_id
}

resource "aws_security_group_rule" "allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr.sgr_id
}

resource "aws_security_group_rule" "allow_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0    #means all ports 
  protocol          = "-1" #means all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr.sgr_id
}

#data call for SSH key 
data "aws_key_pair" "my_key" {
  key_name = "tntk"
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["137112412989"] # AWS official Amazon Linux owner ID
  filter {
    name   = "owner-alias"
    values = ["amazon"]

  }
  filter {
    name   = "name"
    values = ["al2023-ami-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}



##############################################################################################################
#create ec2 instance 
module "aws_instance" {
  source                 = "./modules/ec2_module"
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.al2023.id
  vpc_security_group_ids = module.sgr.sgr_id
  key_name               = data.aws_key_pair.my_key.key_name
  subnet_id              = module.public_subnet1.id
  user_data              = <<EOT
#!/bin/bash
dnf update -y
dnf install httpd -y 
systemctl start httpd
systemctl enable httpd 
echo "<h1>Hello, this is $(hostname -f)</h1>" > /var/www/html/index.html
EOT
  tag                    = "my_ec2_public1"
}


#create ec2 instance 
module "aws_instance2" {
  source                 = "./modules/ec2_module"
  instance_type          = "t2.micro"
  ami                    = data.aws_ami.al2023.id
  vpc_security_group_ids = module.sgr.sgr_id
  key_name               = data.aws_key_pair.my_key.key_name
  subnet_id              = module.public_subnet2.id
  user_data              = <<EOT
#!/bin/bash
dnf update -y
dnf install httpd -y 
systemctl start httpd
systemctl enable httpd 
echo "<h1>Hello, this is $(hostname -f)</h1>" > /var/www/html/index.html
EOT
  tag                    = "my_ec2_public2"
}


#################################################################################################################
#create Target Group 
module "tg" {
  source   = "./modules/target_gr_module"
  name     = "my-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.dev_vpc.aws_vpc #name of the module, then how you named output 
  tg_tag   = "my_tg"
}

### attachment of the target group to instances 
resource "aws_lb_target_group_attachment" "public1_attachment" {
  target_group_arn = module.tg.tg_arn
  target_id        = module.aws_instance.id
}

resource "aws_lb_target_group_attachment" "public2_attachment" {
  target_group_arn = module.tg.tg_arn
  target_id        = module.aws_instance2.id
}

#################################################################################################################

#create Security Group for LB 
module "sgr_lb" {
  source      = "./modules/sgr_module"
  vpc_id      = module.dev_vpc.aws_vpc
  name        = "my_sgr_for_lb"
  description = "LB security group"
}

resource "aws_security_group_rule" "allow_http_lb" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr_lb.sgr_id
}

resource "aws_security_group_rule" "allow_https_lb" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr_lb.sgr_id
}


resource "aws_security_group_rule" "allow_outbound_lb" {
  type              = "egress"
  from_port         = 0
  to_port           = 0    #means all ports 
  protocol          = "-1" #means all protocols
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = module.sgr_lb.sgr_id
}

################################################################################################################
#create LB 
module "lb_module" {
  source                     = "./modules/alb_module"
  name                       = "alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [module.sgr_lb.sgr_id]
  enable_deletion_protection = false
  subnets                    = [module.public_subnet1.id, module.public_subnet2.id]
  load_balancer_arn          = module.lb_module.lb_arn
  target_group_arn           = module.tg.tg_arn
  tag_lb                     = "my_lb"

}
