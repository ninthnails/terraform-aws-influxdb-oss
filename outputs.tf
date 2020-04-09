output "influxdb_api_endpoint" {
  value = join(",", local.is_hosted_zone_provided ? formatlist("%s:8086", aws_route53_record.alias.*.fqdn) : formatlist("%s:8086", aws_network_interface.static.*.private_ip))
}

output "influxdb_admin_endpoint" {
  value = join(",", local.is_hosted_zone_provided ? formatlist("%s:8088", aws_route53_record.alias.*.fqdn) : formatlist("%s:8088", aws_network_interface.static.*.private_ip))
}
