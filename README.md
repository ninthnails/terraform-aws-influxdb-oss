# InfluxDB OSS Terraform module

Terraform module which creates InfluxDB open source (OSS) nodes on AWS EC2.

Note InfluxDB OSS doesn't support clustering and as such, the nodes created are independent.

## Available Features
* Automatic host level provisioning of the latest (v1) version InfluxDB OSS
* Distribute nodes across multiple AZs (based on provided subnets)
* Persistent EBS volumes for faster recovery
* Separate EBS volumes for data and WAL (Write Ahead Log) storage for better performance
* Automatic reboot and EC2 instance recovery on status check failures
* EBS volumes are encrypted
* Host system optimizations (filesystem, limits, network, swap)

## Usage
```hcl
module "influxdb" {
  source = "ninthnails/influxdb-oss/aws"
  version = "1.0.0"
  admin_username = "admin"
  admin_password = "parameter/influxdb-admin-password"
  data_storage_volume_size = 350
  hosted_zone_id = "Z200LS379IE475"
  instance_type = "r5.large"
  key_pair_name = "my-ssh-key-pair-name"
  nodes = 2
  prefix = "example"
  private_subnet_ids = ["subnet-0178794a1983117d", "subnet-d345787d94a31119"]
  storage_type = "ebs"
  tags = {
    Terraform = "true"
    Environment = "prod"
  }
  vpc_id = "vpc-05fbe87d7fea46d75"
  wal_storage_volume_size = 350
}
```

## Examples
* [Single Node for Development](examples/single-dev): A simple node that store data on the root volume.
* [Single Node with EBS](examples/single-ebs): A simple node with EBS volumes.
 