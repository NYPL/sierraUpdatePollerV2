provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-travis-builds-qa"
    key     = "sierra-holding-poller-terraform-state"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../../base"

  environment = "qa"
  deployment_name = "Holding"
  record_env = "holding"
}
