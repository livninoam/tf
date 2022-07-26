data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  region = data.aws_region.current.name
  account_id = data.aws_caller_identity.current.account_id
  ssh_path_location = pathexpand(var.ssh_key_path)
  s3_env_app_bucket_prefix = var.s3_env_app_bucket_prefix

  environment_name  = var.environment_name
  environment_type  = var.environment_type
  common_tags = {
    Environment_type  = local.environment_type
    Environment_name  = local.environment_name
  }


}
