# Single InfluxDB Server Example

Terraform example module which creates an InfluxDB server for development, with no EBS backed data storage.

## Usage
If you already meet the requirements, create an auto variables file such as `example.auto.tfvars` with at minimum these.
Otherwise see further below for more instructions.
```hcl-terraform
admin_password = "parameter/influxdb-admin-password"
aws_region = "us-east-2"
key_pair_name = "my-ssh-key-pair-name"
private_subnet_ids = ["subnet-0178794a1983117d", "..."]
vpc_id = "vpc-05fbe87d7fea46d75"
```

Then run Terraform as usual:
```shell script
terraform workspace new lab
terraform init
terraform plan -out terraform.tfplan
terraform apply terraform.tfplan
```

When you are done, delete the resources.
```shell script
terraform destroy
```

### AWS System Manager Parameter Store
This will create a parameter holding the password for the admin user.
```shell script
aws --region us-east-2 ssm put-parameter --name "influxdb-admin-password" \
  --type SecureString --value CHANGE_IT
```


