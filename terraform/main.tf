data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  az = data.aws_availability_zones.available.names[0]
  common_tags = {
    Project = "EWB-VPC-Peering"
    Student = var.student_name
  }
}

# VPCs and subnets
resource "aws_vpc" "a" {
  cidr_block           = "10.10.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "ewb-vpc-a" })
}

resource "aws_vpc" "b" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = merge(local.common_tags, { Name = "ewb-vpc-b" })
}

resource "aws_subnet" "a_public" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, { Name = "ewb-a-public" })
}

resource "aws_subnet" "a_private" {
  vpc_id                  = aws_vpc.a.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, { Name = "ewb-a-private" })
}

resource "aws_subnet" "b_private" {
  vpc_id                  = aws_vpc.b.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = false
  tags = merge(local.common_tags, { Name = "ewb-b-private" })
}

# Internet gateway and route tables
resource "aws_internet_gateway" "a" {
  vpc_id = aws_vpc.a.id
  tags   = merge(local.common_tags, { Name = "ewb-igw-a" })
}

resource "aws_route_table" "a_public" {
  vpc_id = aws_vpc.a.id
  tags   = merge(local.common_tags, { Name = "ewb-rt-a-public" })
}

resource "aws_route" "a_public_internet" {
  route_table_id         = aws_route_table.a_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.a.id
}

resource "aws_route_table" "a_private" {
  vpc_id = aws_vpc.a.id
  tags   = merge(local.common_tags, { Name = "ewb-rt-a-private" })
}

resource "aws_route_table" "b_private" {
  vpc_id = aws_vpc.b.id
  tags   = merge(local.common_tags, { Name = "ewb-rt-b-private" })
}

resource "aws_route_table_association" "a_public" {
  subnet_id      = aws_subnet.a_public.id
  route_table_id = aws_route_table.a_public.id
}

resource "aws_route_table_association" "a_private" {
  subnet_id      = aws_subnet.a_private.id
  route_table_id = aws_route_table.a_private.id
}

resource "aws_route_table_association" "b_private" {
  subnet_id      = aws_subnet.b_private.id
  route_table_id = aws_route_table.b_private.id
}

# Peering (same account and Region)
resource "aws_vpc_peering_connection" "a_b" {
  vpc_id      = aws_vpc.a.id
  peer_vpc_id = aws_vpc.b.id
  auto_accept = true
  tags        = merge(local.common_tags, { Name = "ewb-a-b-peer" })
}

resource "aws_route" "a_private_to_b" {
  route_table_id            = aws_route_table.a_private.id
  destination_cidr_block    = "10.20.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b.id
}

resource "aws_route" "b_private_to_a" {
  route_table_id            = aws_route_table.b_private.id
  destination_cidr_block    = "10.10.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b.id
}

resource "aws_route" "a_public_to_b" {
  route_table_id            = aws_route_table.a_public.id
  destination_cidr_block    = "10.20.0.0/16"
  vpc_peering_connection_id = aws_vpc_peering_connection.a_b.id
}

# Security groups
resource "aws_security_group" "bastion" {
  name        = "ewb-sg-bastion"
  description = "SSH from student's current public IP only"
  vpc_id      = aws_vpc.a.id
  ingress {
    description = "SSH from administrator"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "ewb-sg-bastion" })
}

resource "aws_security_group" "app_a" {
  name        = "ewb-sg-app-a"
  description = "App-A SSH from bastion and ICMP from App-B"
  vpc_id      = aws_vpc.a.id
  ingress {
    description = "SSH from bastion"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }
  ingress {
    description = "ICMP Echo Request from App-B"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.20.1.10/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "ewb-sg-app-a" })
}

resource "aws_security_group" "app_b" {
  name        = "ewb-sg-app-b"
  description = "App-B SSH from bastion and ICMP from App-A"
  vpc_id      = aws_vpc.b.id
  ingress {
    description = "SSH from bastion private IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.10.1.10/32"]
  }
  ingress {
    description = "ICMP Echo Request from App-A"
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    cidr_blocks = ["10.10.2.10/32"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(local.common_tags, { Name = "ewb-sg-app-b" })
}

resource "aws_key_pair" "lab" {
  key_name   = "ewb-lab"
  public_key = file(pathexpand(var.public_key_path))
  tags       = local.common_tags
}

# EC2 instances
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab.key_name
  subnet_id                   = aws_subnet.a_public.id
  private_ip                  = "10.10.1.10"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = merge(local.common_tags, { Name = "ewb-bastion" })
}

resource "aws_instance" "app_a" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab.key_name
  subnet_id                   = aws_subnet.a_private.id
  private_ip                  = "10.10.2.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_a.id]
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = merge(local.common_tags, { Name = "ewb-app-a" })
}

resource "aws_instance" "app_b" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.lab.key_name
  subnet_id                   = aws_subnet.b_private.id
  private_ip                  = "10.20.1.10"
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.app_b.id]
  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    delete_on_termination = true
  }
  tags = merge(local.common_tags, { Name = "ewb-app-b" })
}
