output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "URL of the deployed application"
  value       = "http://${aws_instance.app.public_ip}"
}

output "ssh_command" {
  description = "Ready-made SSH command"
  value       = "ssh -i ${var.key_name}.pem ubuntu@${aws_instance.app.public_ip}"
}
