#################
# Data and Local Variables
#################
data "aws_region" "this" {
}

data "aws_caller_identity" "this" {
}

data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id    = var.private_subnet_ids[count.index]
}

data "aws_kms_key" "ebs" {
  key_id = var.ebs_kms_key_id
}

data "aws_ami" "amzn2" {
  count      = local.is_image_id_provided ? 0 : 1
  name_regex = "amzn2-ami-hvm-2.0.2020*"
  owners     = ["amazon"]
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "description"
    values = ["Amazon Linux 2 AMI 2.0.2020* x86_64 HVM gp2"]
  }
  filter {
    name   = "ena-support"
    values = ["true"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
  most_recent = true
}

locals {
  is_admin_password_systems_manager = length(regexall("^parameter/.*", var.admin_password)) > 0
  is_admin_password_secrets_manager = length(regexall("^secrets/.*", var.admin_password)) > 0
  is_hosted_zone_provided           = length(var.hosted_zone_id) > 0
  is_image_id_provided              = length(var.image_id) > 0
  instance_type_support_recovery = contains(
    ["a1", "c3", "c4", "c5", "c5n", "m3", "m4", "m5", "m5a", "m5n", "p3", "r3", "r4", "r5", "r5a", "r5n", "t2", "t3", "t3a", "x1", "x1e"],
    split(".", var.instance_type)[0]
  )
  prefix           = length(trimspace(var.prefix)) > 0 ? format("%s-", trimspace(var.prefix)) : ""
  storage_ebs_flag = var.storage_type == "ebs" ? 1 : 0
}

#################
# Security Groups
#################
resource "aws_security_group" "private" {
  name_prefix = "${local.prefix}influxdb-private-"
  vpc_id      = var.vpc_id
  description = "Security group for InfluxDB"
  tags        = merge(var.tags, map("Name", "${local.prefix}influxdb-private"))
}

resource "aws_security_group_rule" "egress-all" {
  from_port         = 0
  protocol          = "all"
  security_group_id = aws_security_group.private.id
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  to_port           = 65535
  type              = "egress"
}

resource "aws_security_group_rule" "ingress-ssh" {
  type              = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = "22"
  to_port   = "22"
  protocol  = "tcp"
}

resource "aws_security_group_rule" "ingress-api" {
  description       = "API"
  type              = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = 8086
  to_port   = 8086
  protocol  = "tcp"
}

resource "aws_security_group_rule" "ingress-admin" {
  description       = "RPC Admin"
  type              = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = 8088
  to_port   = 8088
  protocol  = "tcp"
}

#################
# S3 Bucket
#################
resource "random_id" "s3" {
  byte_length = 16
}

resource "aws_s3_bucket" "source" {
  acl    = "private"
  bucket = substr("${var.prefix}-image-${data.aws_region.this.name}-${random_id.s3.hex}", 0, 63)
  region = data.aws_region.this.name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "source" {
  bucket              = aws_s3_bucket.source.id
  block_public_acls   = false
  block_public_policy = false
}

data "archive_file" "setup" {
  type        = "zip"
  output_path = "${path.module}/setup.zip"
  source_dir  = "${path.module}/ansible"
}

resource "aws_s3_bucket_object" "setup" {
  acl           = "private"
  bucket        = aws_s3_bucket.source.bucket
  content_type  = "application/zip"
  etag          = data.archive_file.setup.output_md5
  key           = "setup.zip"
  source        = data.archive_file.setup.output_path
  storage_class = "ONEZONE_IA"
  tags          = var.tags
}

#################
# IAM
#################
data "aws_iam_policy_document" "assume" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      identifiers = [
        "ec2.amazonaws.com"
      ]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "node" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name_prefix        = "${local.prefix}influxdb-"
  tags               = merge(var.tags, map("Name", "${local.prefix}influxdb"))
}

resource "aws_iam_instance_profile" "node" {
  name_prefix = "${local.prefix}influxdb-"
  role        = aws_iam_role.node.id
}

data "aws_iam_policy_document" "s3" {
  statement {
    actions = [
      "s3:Get*"
    ]
    effect = "Allow"
    resources = [
      "${aws_s3_bucket.source.arn}/*"
    ]
  }
}

data "aws_iam_policy_document" "system-manager" {
  count = local.is_admin_password_systems_manager ? 1 : 0
  statement {
    actions = [
      "ssm:GetParameter"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:${var.admin_password}"
    ]
  }
}

data "aws_iam_policy_document" "secrets-manager" {
  count = local.is_admin_password_secrets_manager ? 1 : 0
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:secret:${regex("secrets/(.*)", var.admin_password)[0]}"
    ]
  }
}

resource "aws_iam_role_policy" "s3" {
  name_prefix = "s3-"
  policy      = data.aws_iam_policy_document.s3.json
  role        = aws_iam_role.node.id
}

resource "aws_iam_role_policy" "ssm" {
  count       = local.is_admin_password_systems_manager ? 1 : 0
  name_prefix = "system-manager-"
  policy      = data.aws_iam_policy_document.system-manager[0].json
  role        = aws_iam_role.node.id
}

resource "aws_iam_role_policy" "secrets-manager" {
  count       = local.is_admin_password_secrets_manager ? 1 : 0
  name_prefix = "secrets-manager-"
  policy      = data.aws_iam_policy_document.secrets-manager[0].json
  role        = aws_iam_role.node.id
}


#################
# EBS Storage
#################
resource "aws_ebs_volume" "data" {
  count             = var.nodes * local.storage_ebs_flag
  availability_zone = data.aws_subnet.private[count.index % length(data.aws_subnet.private)].availability_zone
  encrypted         = true
  iops              = var.data_storage_volume_type == "io1" ? var.data_storage_volume_iops : null
  kms_key_id        = data.aws_kms_key.ebs.arn
  size              = var.data_storage_volume_size
  type              = var.data_storage_volume_type
  tags              = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}-data"))
  lifecycle {
    ignore_changes = [
      encrypted,
      kms_key_id,
      snapshot_id,
      type
    ]
  }
}

resource "aws_ebs_volume" "wal" {
  count             = var.nodes * local.storage_ebs_flag
  availability_zone = data.aws_subnet.private[count.index % length(data.aws_subnet.private)].availability_zone
  encrypted         = true
  iops              = var.wal_storage_volume_type == "io1" ? var.wal_storage_volume_iops : null
  kms_key_id        = data.aws_kms_key.ebs.arn
  size              = var.wal_storage_volume_size
  type              = var.wal_storage_volume_type
  tags              = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}-wal"))
  lifecycle {
    ignore_changes = [
      encrypted,
      kms_key_id,
      snapshot_id,
      type
    ]
  }
}


#################
# EC2 Instance
#################
data "template_file" "user_data" {
  count    = local.is_image_id_provided ? 0 : 1
  template = file("${path.module}/files/init.sh")
  vars = {
    admin_username  = var.admin_username
    admin_password  = var.admin_password
    storage_type    = var.storage_type
    region          = data.aws_region.this.name
    flux_enabled    = var.flux_enabled
    setup_dist      = "s3://${aws_s3_bucket_object.setup.bucket}/${aws_s3_bucket_object.setup.key}"
    setup_dist_etag = aws_s3_bucket_object.setup.etag
  }
}

resource "aws_instance" "node" {
  count                = var.nodes
  ami                  = local.is_image_id_provided ? var.image_id : data.aws_ami.amzn2[0].id
  iam_instance_profile = aws_iam_instance_profile.node.id
  instance_type        = var.instance_type
  lifecycle {
    create_before_destroy = true
  }
  ebs_optimized = var.ec2_ebs_optimized
  credit_specification {
    cpu_credits = var.ec2_cpu_credits
  }
  key_name = var.key_pair_name
  root_block_device {
    volume_size = var.root_volume_size
    encrypted   = true
  }
  subnet_id = data.aws_subnet.private[count.index % length(data.aws_subnet.private)].id
  tags      = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}"))
  user_data = local.is_image_id_provided ? var.ec2_user_data : data.template_file.user_data[0].rendered
  vpc_security_group_ids = [
    aws_security_group.private.id
  ]
}

#################
# Static Network Interface
#################
resource "aws_network_interface" "static" {
  count = var.nodes
  security_groups = [
    aws_security_group.private.id
  ]
  subnet_id = data.aws_subnet.private[count.index % length(data.aws_subnet.private)].id
  tags      = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}"))
}

resource "aws_network_interface_attachment" "static" {
  count                = var.nodes
  device_index         = 1
  instance_id          = aws_instance.node[count.index].id
  network_interface_id = aws_network_interface.static[count.index].id
}

#################
# EBS Storage Attachments
#################
resource "aws_volume_attachment" "data" {
  count        = var.nodes * local.storage_ebs_flag
  device_name  = "/dev/sdf"
  instance_id  = aws_instance.node[count.index].id
  volume_id    = aws_ebs_volume.data[count.index].id
  force_detach = true
}

resource "aws_volume_attachment" "wal" {
  count        = var.nodes * local.storage_ebs_flag
  device_name  = "/dev/sdg"
  instance_id  = aws_instance.node[count.index].id
  volume_id    = aws_ebs_volume.wal[count.index].id
  force_detach = true
}

#################
# Recovery
#################
resource "aws_cloudwatch_metric_alarm" "reboot" {
  count = local.instance_type_support_recovery ? var.nodes : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.this.name}:ec2:reboot"
  ]
  alarm_description   = "Reboot Linux instance when Instance status check failed for 5 minutes"
  alarm_name          = "${local.prefix}influxdb-${format("%02d", count.index + 1)}-reboot"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 5
  evaluation_periods  = 5
  threshold           = 1
  metric_name         = "StatusCheckFailed_Instance"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  dimensions = {
    InstanceId = aws_instance.node[count.index].id
  }
  tags = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}-reboot"))
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudwatch_metric_alarm" "recovery" {
  count = local.instance_type_support_recovery ? var.nodes : 0
  alarm_actions = [
    "arn:aws:automate:${data.aws_region.this.name}:ec2:recover"
  ]
  alarm_description   = "Recover Linux instance when System status check failed for 10 minutes"
  alarm_name          = "${local.prefix}influxdb-${format("%02d", count.index + 1)}-recovery"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  datapoints_to_alarm = 10
  evaluation_periods  = 10
  threshold           = 1
  metric_name         = "StatusCheckFailed_System"
  namespace           = "AWS/EC2"
  period              = 60
  statistic           = "Maximum"
  dimensions = {
    InstanceId = aws_instance.node[count.index].id
  }
  tags = merge(var.tags, map("Name", "${local.prefix}influxdb-${format("%02d", count.index + 1)}-recovery"))
  lifecycle {
    create_before_destroy = true
  }
}

#################
# Routing
#################
resource "aws_route53_record" "alias" {
  count = local.is_hosted_zone_provided ? var.nodes : 0
  name  = "${local.prefix}influxdb-${format("%02d", count.index + 1)}"
  records = [
    aws_network_interface.static[count.index].private_ip
  ]
  ttl     = 3600
  type    = "A"
  zone_id = var.hosted_zone_id
}
