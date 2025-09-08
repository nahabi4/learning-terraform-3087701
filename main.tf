data "aws_ami" "app_ami" {
  most_recent = true

  filter {
    name   = "name"
    values = [var.ami_filter.name]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = [var.ami_filter.owner] 
}

data "aws_vpc" "default" {
  default = true
}

module "blog_vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = var.environment.name
  cidr = "${var.environment.netwrok_prefix}.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]
  public_subnets  = ["${var.environment.netwrok_prefix}.101.0/24", "${var.environment.netwrok_prefix}.102.0/24", "${var.environment.netwrok_prefix}.103.0/24"]

  tags = {
    Terraform = "true"
    Environment = "dev"
  }
}


module "autoscaling" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "9.0.1"
  # insert the 1 required variable here

  name = "${var.environment.netwrok_prefix}-blog"
  min_size = var.asg_min_size
  max_size = var.asg_max_size

  vpc_zone_identifier = module.blog_vpc.public_subnets

  security_groups = [module.blog_sg.security_group_id]  

  image_id           = data.aws_ami.app_ami.id
  instance_type = var.instance_type
}

resource "aws_autoscaling_attachment" "asg_attachment" {
  autoscaling_group_name = module.autoscaling.autoscaling_group_id
  lb_target_group_arn   = module.blog_alb.target_group_arns[0]
}

module "blog_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.3.0"
  name = "${var.environment.netwrok_prefix}-blog-sg"

  vpc_id = module.blog_vpc.vpc_id

  ingress_rules = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]
}

module "blog_alb" {
  source = "terraform-aws-modules/alb/aws"
  version = "~> 6.0"

  name    = "${var.environment.netwrok_prefix}-blog-alb"
  vpc_id  = module.blog_vpc.vpc_id
  subnets = module.blog_vpc.public_subnets
  security_groups = [module.blog_sg.security_group_id]

  target_groups = [
    {
      name_prefix = "${var.environment.name}-"
      backend_protocol = "HTTP"
      backend_port = 80
      target_type = "instance"

    }

  ]

  http_tcp_listeners = [
    {
      port = 80
      protocol = "HTTP"
      target_group_index = 0
    }
  ]

  tags = {
    Environment = var.environment.netwrok_prefix
  }
}


