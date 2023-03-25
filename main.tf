terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.60.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}

#Create VPC
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.10.0.0/16"
  instance_tenancy     ="default"
  enable_dns_hostnames = true

  tags = {
    name = "main_vpc"
  }
}


# Create Public Subnet
resource "aws_subnet" "Subnet_public" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.10.1.0/24"
  availability_zone       = "ca-central-1a"
  map_public_ip_on_launch = true

  tags = {
    name = "Subnet_public"
  }
}

#Create Private Subnet
resource "aws_subnet" "Subnet_private" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.10.2.0/24"
  availability_zone       = "ca-central-1a"
  map_public_ip_on_launch = true

  tags  = {
    name = "Subnet_private"
  }
}

#Attach internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id

  tags = {
    name = "igw"
  }
}

#Create Route tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    name = "public_route_table"
  }
}

#Create route table association
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.Subnet_public.id
  route_table_id = aws_route_table.public_route_table.id
}

#Create Security groups
resource "aws_security_group" "web_security_group" {
  name   = "allow http and ssh"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#CReate EC2 instance
resource "aws_instance" "EC2_instance" {
  ami           = "ami-06c0b4ddc1eb5ce76"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.Subnet_public.id
  vpc_security_group_ids      = [aws_security_group.web_security_group.id]
  associate_public_ip_address = true

  user_data = <<EOF
  #!/bin/bash 

  sudo yum update -y 
  sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
  sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io.key
 
  sudo yum upgrade -y
  sudo amazon-linux-extras install java-openjdk11 -y
  sudo yum install jenkins -y
  sudo systemctl enable jenkins
  sudo systemctl start jenkins
  EOF
}

#Create S3 bucket for Jenkins artifacts
resource "aws_s3_bucket" "jenkins_artifacts_20220324" {
  bucket = "jenkins-artifacts20220324"
}