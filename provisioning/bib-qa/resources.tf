provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-travis-builds-qa"
    key     = "sierra-poller-state-qa"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../base"

  environment = "qa"
  record_type = "Bib"

  vpc_config = {
    subnet_ids         = ["subnet-21a3b244", "subnet-f35de0a9"]
    security_group_ids = ["sg-aa74f1db"]
  }

}
