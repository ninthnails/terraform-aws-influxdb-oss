#################
# Variables
#################
variable "admin_password" {
  default = "example"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "hosted_zone_id" {
  default = ""
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
provider "aws" {
  region = var.aws_region
}

#################
# Modules
#################
module "influxdb" {
  source = "../../"
  admin_username = "admin"
  admin_password = var.admin_password
  data_storage_volume_size = 4
  hosted_zone_id = var.hosted_zone_id
  instance_type = "t3a.small"
  key_pair_name = var.key_pair_name
  nodes = 1
  prefix = "ebs-example"
  private_subnet_ids = var.private_subnet_ids
  storage_type = "ebs"
  tags = {
    Terraform = "true"
    Environment = "dev"
  }
  vpc_id = var.vpc_id
  wal_storage_volume_size = 5
}

#################
# Outputs
#################
output "influxdb_api_endpoint" {
  value = module.influxdb.influxdb_api_endpoint
}

output "influxdb_admin_endpoint" {
  value = module.influxdb.influxdb_admin_endpoint
}
