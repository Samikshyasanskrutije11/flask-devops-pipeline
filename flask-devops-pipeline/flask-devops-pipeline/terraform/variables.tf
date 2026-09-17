variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Name prefix for all resources"
  type        = string
  default     = "flask-devops"
}

variable "instance_type" {
  description = "EC2 instance type (t2.micro and t3.micro are free-tier eligible)"
  type        = string
  default     = "t2.micro"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair used for SSH access"
  type        = string
}

variable "ssh_allowed_cidr" {
  description = "CIDR allowed to SSH. Use your own IP/32 in real use."
  type        = string
  default     = "0.0.0.0/0"
}

variable "environment" {
  description = "Environment tag"
  type        = string
  default     = "production"
}
