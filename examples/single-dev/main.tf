#################
# Variables
#################
variable "admin_password" {
  default = "example"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "key_pair_name" {
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "vpc_id" {
}

#################
# Providers
#################
provider "archive" {
  version = "~> 1.3.0"
}

provider "aws" {
  region = var.aws_region
  version = "~> 2.56"
}

provider "template" {
  version = "~> 2.1"
}

#################
# Modules
#################
module "influxdb" {
  source = "../../"
  admin_username = "admin"
  admin_password = "example"
  instance_type = "t3a.micro"
  key_pair_name = var.key_pair_name
  prefix = "example"
  private_subnet_ids = var.private_subnet_ids
  root_volume_size = 32
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
  vpc_id = var.vpc_id
}
