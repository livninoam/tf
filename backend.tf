terraform {
  required_version = ">= 0.12.2"

  backend "s3" {
    region         = "us-east-1"
    bucket         = "terraform-489605076284-env-prod1-prod-state"
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-489605076284-env-prod1-prod-state-lock"
    profile        = ""
    role_arn       = ""
    encrypt        = "true"
  }
}
