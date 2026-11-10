output "vpc_a_id" {
  value = aws_vpc.a.id
}

output "vpc_b_id" {
  value = aws_vpc.b.id
}

output "peering_connection_id" {
  value = aws_vpc_peering_connection.a_b.id
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "bastion_private_ip" {
  value = aws_instance.bastion.private_ip
}

output "app_a_private_ip" {
  value = aws_instance.app_a.private_ip
}

output "app_b_private_ip" {
  value = aws_instance.app_b.private_ip
}

output "instance_ids" {
  value = {
    bastion = aws_instance.bastion.id
    app_a   = aws_instance.app_a.id
    app_b   = aws_instance.app_b.id
  }
}

output "ssh_config_hint" {
  value = "Use bastion_public_ip in the README SSH config; connect to App-A/App-B with ProxyJump."
}
