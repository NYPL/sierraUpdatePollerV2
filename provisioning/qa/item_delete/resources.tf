provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-travis-builds-qa"
    key     = "sierra-item-delete-poller-terraform-state"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../../base"

  environment = "qa"
  deployment_name = "ItemDelete"
  record_env = "item-delete"
}
