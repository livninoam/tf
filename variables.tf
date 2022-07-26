variable "environment_name" {
  type = string
  description = "The name of the environment . will be used in the resources names and tags  "
}

variable "environment_type" {
  type = string
  description = "The environment type . will be used in the resources tage  "

  validation {
    condition     = can(regex("^(dev|test|prod|stage)$", var.environment_type))
    error_message = "Environment_type must be dev|test|prod|stage."
  }
}

variable "image_id" {
  type = string
  description = "AML2 image"
}

variable "instance_type" {
  type = string
  description = "instance type  "
  
}

variable "ssh_key_path" {
  type = string
  description = "ssh keys path"
  default = "~/.ssh"
}

variable "generate_ssh_key" {
  type        = bool
  description = "Whether or not to generate an SSH key"
  default =  true
}

variable "public_subnets" {
  description = "list of public subnets "
  type        = list(string)
}

variable "vpc_id" {
  description = "vpc id "
  type        = string
}


# todo fix to private_subnet
variable "vpc_zone_identifier" {
  description = "list of private subnets "
  type        = list(string)
}

variable "database_subnets" {
  description = "list of public subnets "
  type        = list(string)
}

variable "allowed_ingress_cidr_blocks" {
  description = "list of alowed IPs to access env resources   "
  type        = list(string)
}


variable "app_version" {
  description = "Applications version"
  type        = string
  default = "1"
}

variable "s3_env_app_bucket_prefix" {
  description = "Prefix for applications bucket "
  type        = string
  default = "env"
}

variable "certificate_arn" {
  description = "alb certificate"
  type        = string
}

variable "rds_deletion_protection" {
  type        = bool
  description = "Whether or not should be rds deletion protection"
  default =  false
}

variable "rds_backup_retention_period" {
  type        = number
  description = "The number of days that the back save backwards"
  default =  0
}