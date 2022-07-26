
#data "template_file" "user_data_file" {
# template = "${file("${path.module}/userdata.sh")}"
# vars =  {
#  app_version = var.app_version
#}

#}
data "aws_iam_instance_profile" "ec2_application_instance_profile" {
  name = "ec2_application_instance_profile"
}

# TODO future
#data "template_file" "user_data" {
#template = "${file("userdata.sh")}"
#}


module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 4.4"

  # Autoscaling group
  name = "asg ec2 ${var.environment_name} api"

  min_size                  = 1
  max_size                  = 1
  desired_capacity          = 1
  wait_for_capacity_timeout = 0
  health_check_type         = "EC2"
  vpc_zone_identifier       = var.vpc_zone_identifier
  iam_instance_profile_arn = "${data.aws_iam_instance_profile.ec2_application_instance_profile.arn}"
  target_group_arns =  "${module.alb.target_group_arns}" 

  initial_lifecycle_hooks = [
    {
      name                  = "ExampleStartupLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_LAUNCHING"
      notification_metadata = jsonencode({ "hello" = "world" })
    },
    {
      name                  = "ExampleTerminationLifeCycleHook"
      default_result        = "CONTINUE"
      heartbeat_timeout     = 60
      lifecycle_transition  = "autoscaling:EC2_INSTANCE_TERMINATING"
      notification_metadata = jsonencode({ "goodbye" = "world" })
    }
  ]

  # from account setup
  instance_refresh = {
    strategy = "Rolling"
    preferences = {
      min_healthy_percentage = 50
    }
    triggers = ["tag"]
  }

  # Launch template
  lt_name                = "${var.environment_name}-asg-lt"
  description            = "Launch template for application asg"
  key_name  = module.aws_key_pair.key_name
  update_default_version = true

  use_lt    = true
  create_lt = true

  image_id          = var.image_id

  instance_type     = var.instance_type
  ebs_optimized     = true
  enable_monitoring = true

  block_device_mappings = [
    {
      # Root volume
      device_name = "/dev/xvda"
      no_device   = 0
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 8
        volume_type           = "gp3"
      }
      }, {
      device_name = "/dev/sda1"
      no_device   = 1
      ebs = {
        delete_on_termination = true
        encrypted             = true
        volume_size           = 10
        volume_type           = "gp3"
      }
    }
  ]

  metadata_options = {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 32
  }

  network_interfaces = [
    {
      delete_on_termination = true
      description           = "eth0"
      device_index          = 0
      security_groups       = [ "${module.ec2_sg.security_group_id}" ]
    }
  ]

 tags_as_map = local.common_tags 

# https://github.com/terraform-aws-modules/terraform-aws-autoscaling/issues/149
# consider -  https://github.com/terraform-aws-modules/terraform-aws-autoscaling/issues/57
 #user_data_base64  = base64encode (file("./userdata.sh"))
 user_data_base64  = base64encode (templatefile("userdata.sh", { app_version_tf = var.app_version ,environment_name = var.environment_name ,s3_env_app_bucket = module.s3_bucket.s3_bucket_arn  }) )
  depends_on = [
    aws_secretsmanager_secret_version.rds_credentials,
  ]
}
