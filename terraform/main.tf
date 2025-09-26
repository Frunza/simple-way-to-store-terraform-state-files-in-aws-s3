terraform {
  required_version = "1.5.0"
  # Configure the backend to store the terraform state files
  # Credentials can be provided by using the AWS_ACCESS_KEY_ID and AWS_SECRET_KEY environment variables. (https://developer.hashicorp.com/terraform/language/backend/s3)
  backend "s3" {
    bucket = "aws-sf-home-s3-remote-terraform-state-files"
    key    = "test-project/terraform.tfstate"
    region = "eu-central-1"
  }
}