variable "admin_username" {
  default     = "admin"
  description = "The name for the administrator user."
}

variable "admin_password" {
  default     = ""
  description = <<DOC
  The reference to a SSM Parameter Store parameter or Secrets Manager secret for the password of the administrator user of the manager tools.
  Prefix with "parameter/" for a Parameter Store parameter.
  Prefix with "secret/" for a Secrets Manager secret.
  Support also clear text value for ease of development.
  DOC
}

variable "ebs_kms_key_id" {
  default     = "alias/aws/ebs"
  description = "The ID of the KMS key to be used for encrypting EBS volumes."
}

variable "ec2_ebs_optimized" {
  default     = false
  description = "If true, the launched EC2 instance will be EBS-optimized."
}

variable "ec2_cpu_credits" {
  default     = "standard"
  description = "The credit option for CPU usage. Can be standard or unlimited. T3 instances are launched as unlimited by default."
}

variable "ec2_user_data" {
  default = ""
  description = <<DOC
  The data to pass to the EC2 instances at startup. If none provided (left blank) the default provisioning of InfluxDB will be used.
  NOTE: the default provisioning only supports Amazon Linux 2 type of AMI.
  DOC
}

variable "data_storage_volume_type" {
  default     = "gp2"
  description = "The type of EBS volume used for the InfluxDB data store."
}

variable "data_storage_volume_iops" {
  default     = 1000
  description = "The number of IOPS for the data store EBS volume. Only valid if the corresponding volume type is io1."
}

variable "data_storage_volume_size" {
  default     = 1
  description = "The size in GiB for the data store EBS volume."
}

variable "hosted_zone_id" {
  default     = ""
  description = "ID of the Route 53 Zones where domain names will created. If none provided no domain names are created."
}

variable "instance_type" {
  default     = "t3a.nano"
  description = "The type of EC2 instance to be used for the EC2 instances."
}

variable "image_id" {
  default     = ""
  description = <<DOC
  The ID of the AMI (Amazon Machine Image) to use for creating the instances.
  When none provided (empty string) the latest Amazon Linux 2 image is used.
  DOC
}

variable "key_pair_name" {
  description = "The name of the SSH key pair that will be assigned to EC2 instances."
}

variable "nodes" {
  default     = 1
  description = "The number of node to be created."
}

variable "prefix" {
  default     = ""
  description = "Resources will be prefixed with this."
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "ID of the private subnets in the VPC where resources will be created."
}

variable "root_volume_size" {
  default     = null
  description = "The size in GiB for the root EBS volume on the EC2 instances."
}

variable "storage_type" {
  default     = "root"
  description = "The type of storage used for the EC2 instances. Valid values are: ebs, instance, root."
}

variable "tags" {
  default     = {}
  description = "A mapping of tags to assign to all resources."
  type        = map(string)
}

variable "vpc_id" {
  description = "ID of the VPC where to create the image."
}

variable "wal_storage_volume_size" {
  default     = 1
  description = "The size in GiB for the WAL store EBS volume."
}

variable "wal_storage_volume_iops" {
  default     = 1000
  description = "The number of IOPS for the WAL store EBS volume. Only valid if the corresponding volume type is io1."
}

variable "wal_storage_volume_type" {
  default     = "gp2"
  description = "The type of EBS volume used for the InfluxDB WAL (Write Ahead Log) store."
}
