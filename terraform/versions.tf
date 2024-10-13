terraform {
  backend "s3" {
    bucket = "terraform-state-382c0d"
    key    = "tf-state/serverless-with-terraform"
    region = "us-west-2"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-west-2"
  default_tags {
    tags = {
      Environment = "prod"
      Owner       = "TFProviders"
      Project     = "ServerlessWithTerraform"
    }
  }
}