variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "ap-south-1"
}

variable "project" {
  description = "Project name, used as a prefix for resource names and tags."
  type        = string
  default     = "taskboard"
}

variable "instance_type" {
  description = "EC2 instance type for the TaskBoard host."
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "admin_cidr" {
  description = "CIDR allowed to reach admin surfaces: SSH (22), Grafana (3001) and Prometheus (9090). Set this to your own IP, e.g. \"203.0.113.10/32\"."
  type        = string
  default     = "0.0.0.0/0"
}

variable "key_name" {
  description = "Name of an existing EC2 key pair for SSH access. Leave empty to skip (you can still use EC2 Instance Connect / SSM)."
  type        = string
  default     = ""
}

variable "repo_url" {
  description = "Git repository cloned by the bootstrap script on the instance."
  type        = string
  default     = "https://github.com/Samir-Khadka/taskboard-devops.git"
}
