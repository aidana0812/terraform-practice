#create vpc 
module "dev_vpc" {
  #name can be anything/how we want to name (for terraform) 
  source     = "./modules/vpc_module"
  cidr_block = "10.0.0.0/16"
  name       = "my_vpc" #name for aws 
}
##############################################################################################################
#create subnet
module "subnets" {
  source = "./modules/subnet_module"
  for_each = {
    public1a  = ["10.0.0.0/18", "us-east-1a", true]
    public1b  = ["10.0.128.0/18", "us-east-1b", true]
    private1a = ["10.0.64.0/18", "us-east-1c", false]
    private1b = ["10.0.192.0/18", "us-east-1d", false]

  }
  vpc_id                  = module.dev_vpc.aws_vpc
  cidr_block              = each.value[0]
  availability_zone       = each.value[1]
  map_public_ip_on_launch = each.value[2]
  subnet_tag              = each.key
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
  subnet_id = module.subnets["public1a"].id
  nat_tag   = "my_nat"

}
##############################################################################################################
#create PUBLIC Route Table and Assocciation 
module "public_rtb" {
  source         = "./modules/rtb_module"
  vpc_id         = module.dev_vpc.aws_vpc
  gateway_id     = module.igw.idw_id
  nat_gateway_id = null
  subnets = [
    module.subnets["public1a"].id,
    module.subnets["public1b"].id
  ]
}

#create PRIVATE route table and assoc 
module "private_rtb" {
  source         = "./modules/rtb_module"
  vpc_id         = module.dev_vpc.aws_vpc
  gateway_id     = null
  nat_gateway_id = module.nat.nat_id
  subnets = [
    module.subnets["private1a"].id,
    module.subnets["private1b"].id
  ]
}


#create aws_route 
resource "aws_route" "aws_route_private" {
  route_table_id         = module.private_rtb.rtb_id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = module.nat.nat_id
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
  subnet_id              = module.subnets["public1a"].id
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
  subnet_id              = module.subnets["public1b"].id
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
  subnets                    = [module.subnets["public1a"].id, module.subnets["public1b"].id]
  load_balancer_arn          = module.lb_module.lb_arn
  target_group_arn           = module.tg.tg_arn
  tag_lb                     = "my_lb"

}

################################################################################################################
#create security group for MYSQL RDS 

module "sgr_rds" {
  source      = "./modules/sgr_and_rule_module"
  name        = "rds-sgr"
  vpc_id      = module.dev_vpc.aws_vpc
  description = "rds-sgr"

  sg_rules = {
    "mysql_aurora"  = ["ingress", 3306, 3306, "tcp", module.sgr.sgr_id]
    "outbound_rule" = ["egress", 0, 0, "-1", "0.0.0.0/0"]
  }

}

#create subnet group for RDS 
module "db_subnet_gr" {
  source     = "./modules/rds_subnet_group_module"
  name       = "db_subnet_group"
  subnet_ids = [module.subnets["private1a"].id, module.subnets["private1b"].id]
  tag        = "db_subnet_group"

}

#create RDS instance 
module "rds_instance" {
  source            = "./modules/rds_instance_module"
  allocated_storage = 20
  engine            = "mysql"
  engine_version    = "5.7.44"
  name              = "secret_db"
  instance_class    = "db.t3.micro"
  username          = local.credential.USERNAME
  password          = local.credential.PASSWORD
  # with the help of secret manager and data call, we can safely store our credentials in AWS secret Manager 
  # BUT credentials will be still in state file -- that's why it is IMPORTANT to securely and propely store state file 

  vpc_security_group_ids = [module.sgr_rds.sgr_id]
  db_subnet_group_name   = module.db_subnet_gr.db_subnet_id
}

data "aws_secretsmanager_secret_version" "credential" {
  secret_id = "rds.credentials"
}


#will use data call for secret manager and convert (decode) it from Json format to a plain text format 
locals {
  credential = jsondecode(data.aws_secretsmanager_secret_version.credential.secret_string)
}
