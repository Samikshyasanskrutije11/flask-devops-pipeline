terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Optional: keep state in S3 so Jenkins builds share it.
  # backend "s3" {
  #   bucket = "my-tfstate-bucket"
  #   key    = "flask-devops-pipeline/terraform.tfstate"
  #   region = "ap-south-1"
  # }
}

provider "aws" {
  region = var.aws_region
}
