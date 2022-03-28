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
  # TO DO: create for_each so qa push does all three record types from this file
  source = "../base"

  environment = "qa"
  record_type = "Bib"

}
