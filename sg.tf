module "ec2_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  name        = "ec2-sg-${var.environment_name}"
  vpc_id      = var.vpc_id
  description = "EC2 security group for ${var.environment_name}"
  ingress_cidr_blocks = var.allowed_ingress_cidr_blocks
  ingress_rules       = ["http-80-tcp","https-443-tcp"]
  egress_rules       = ["https-443-tcp"]
  tags = local.common_tags

  computed_egress_with_source_security_group_id = [
    {
      rule                     = "postgresql-tcp"
      source_security_group_id = module.rds_pg_sg.security_group_id
    }
  ]
  
  computed_egress_with_cidr_blocks  = [
    {
      rule         = "ssh-tcp"
      cidr_blocks  = "52.201.169.199/32" 
    }
  ]

   number_of_computed_egress_with_source_security_group_id = 1
   number_of_computed_egress_with_cidr_blocks = 1
}


module "alb_http_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  name        = "alb-sg-${var.environment_name}"
  vpc_id      = var.vpc_id
  description = "ALB security group for ${var.environment_name}"
  ingress_cidr_blocks = var.allowed_ingress_cidr_blocks
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
 
  computed_egress_with_source_security_group_id = [
    {
      rule                     = "http-80-tcp"
      source_security_group_id = module.ec2_sg.security_group_id
    },
    {
      rule                     = "https-443-tcp"
      source_security_group_id = module.ec2_sg.security_group_id
    }
  ]
   number_of_computed_egress_with_source_security_group_id = 1
  tags = local.common_tags
}

module "rds_pg_sg" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.3"

  name        = "rds-pg-sg-${var.environment_name}"
  vpc_id      = var.vpc_id
  description = "RDS security group for ${var.environment_name}"
  ingress_cidr_blocks = var.allowed_ingress_cidr_blocks
  ingress_rules       = ["postgresql-tcp"]
  tags = local.common_tags
}
