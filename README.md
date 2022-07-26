# Terraform env setup
### Overview
Install environment level resources such as EC2.

### Preparation
Update the file terraform-config/prod/us-east-1/region.tfvars using the outputs of the account setup
### Setup
Get the backend details

#### cd terraform-env-setup

#### cat ../terraform-backend-setup/backend.tf-env-prod1-generated | egrep  'bucket|dynamodb_table'

run the following command with the output from above, for example:

ti $TF_INIT_PARAMS

Apply the changes following commands:

ta

Destroy

Run the following commands:

td
