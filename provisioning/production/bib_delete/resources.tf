provider "aws" {
  region     = "us-east-1"
}

terraform {
  # Use s3 to store terraform state
  backend "s3" {
    bucket  = "nypl-travis-builds-production"
    key     = "sierra-bib-delete-poller-terraform-state"
    region  = "us-east-1"
  }
}

module "base" {
  source = "../../base"

  environment = "production"
  deployment_name = "BibDelete"
  record_env = "bib-delete"
}
