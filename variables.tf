variable "project_name" {
  type        = string
  description = "Prefix used in resource Name tags"
  default = "name"
}

variable "environment" {
  type        = string
  description = "Environment name used in Name tags, e.g. dev"
  default = "env"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
  default = "vpc_cidr"

}

variable "public_subnet_cidr" {
  type        = string
  description = "CIDR block for the public subnet (must sit inside vpc_cidr)"
  default = "public_subnet_cidr"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type (x86_64)"
  default = "t3.micro"
}

variable "key_name" {
  type        = string
  default     = null
  description = "Name of an existing EC2 key pair; null means no key pair (no SSH)"
}
