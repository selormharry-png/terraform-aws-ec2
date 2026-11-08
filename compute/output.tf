output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "instance_id" {
  value = aws_instance.this.id
}

output "instance_public_ip" {
  value = aws_instance.this.public_ip
}

output "security_group_id" {
  value = aws_security_group.ssh.id
}

output "ssh_command" {
  value = "ssh -i <path-to-your-key>.pem ec2-user@${aws_instance.this.public_ip}"
}
