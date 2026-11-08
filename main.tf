
# Network: VPC, IGW, public subnet, routing

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-subnet"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}


# Compute: security group, EC2 instance

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

data "http" "my_ip" {
  url = "https://checkip.amazonaws.com"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not get public IP from checkip.amazonaws.com."
    }
  }
}

resource "aws_security_group" "ssh" {
  name        = "${var.project_name}-${var.environment}-ssh-sg"
  description = "Allow SSH inbound, all outbound"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-ssh-sg"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.ssh.id
  description       = "SSH"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = "${chomp(data.http.my_ip.response_body)}/32"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.ssh.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_instance" "this" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.ssh.id]

  metadata_options {
    http_tokens = "required" # enforce IMDSv2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-ec2"
  }
}
