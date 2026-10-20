terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state (recommended for anything beyond a demo): create the
  # bucket + DynamoDB table once, then uncomment and `terraform init`.
  #
  # backend "s3" {
  #   bucket         = "taskboard-terraform-state"
  #   key            = "taskboard/terraform.tfstate"
  #   region         = "ap-south-1"
  #   dynamodb_table = "taskboard-terraform-locks"
  #   encrypt        = true
  # }
}
