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
  # for_each so qa push does all three record types from this file:
  #
  # for_each = {
  #   bib = "Bib", item = "Item", holding = "Holding"
  # }
  # record_type = each.value
  source = "../base"
  publish = true

  environment = "qa"
  record_type = "Bib"
}
