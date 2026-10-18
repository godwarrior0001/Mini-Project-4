terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "academic_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "academic-vpc" }
}

resource "aws_internet_gateway" "academic_igw" {
  vpc_id = aws_vpc.academic_vpc.id
  tags   = { Name = "academic-igw" }
}

resource "aws_subnet" "academic_public_subnet" {
  vpc_id                  = aws_vpc.academic_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags                    = { Name = "academic-public-subnet" }
}

resource "aws_route_table" "academic_rt" {
  vpc_id = aws_vpc.academic_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.academic_igw.id
  }
  tags = { Name = "academic-route-table" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.academic_public_subnet.id
  route_table_id = aws_route_table.academic_rt.id
}

resource "aws_security_group" "academic_sg" {
  name        = "academic-app-sg"
  description = "Allow SSH, HTTP, and App Port 8080"
  vpc_id      = aws_vpc.academic_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP Nginx"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Student App Direct"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_s3_bucket" "academic_backups" {
  bucket        = "academic-platform-backups-store-2026"
  force_destroy = true
}

resource "aws_instance" "app_server" {
  ami                    = "ami-0fc5d935ebf8bc3bc" # Ubuntu 22.04 LTS us-east-1
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.academic_public_subnet.id
  vpc_security_group_ids = [aws_security_group.academic_sg.id]
  key_name               = "aws-default-key"

  tags = { Name = "academic-app-server" }
}
