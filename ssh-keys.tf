


module "aws_key_pair" {
  source              = "cloudposse/key-pair/aws"
  version             = "0.18.0"
  # name will be prod1-ssh-key
  name = var.environment_name
  attributes          = ["ssh", "key"]
  #ssh_public_key_path = var.ssh_key_path
  ssh_public_key_path = local.ssh_path_location
  generate_ssh_key    = var.generate_ssh_key

}

