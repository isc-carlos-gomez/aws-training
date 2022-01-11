##################################################################################
# PROVIDERS
##################################################################################

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}


##################################################################################
# RESOURCES
##################################################################################

## NETWORKING

resource "aws_vpc" "web-vpc" {
  cidr_block       = "10.10.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name        = "development-web-vpc"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

resource "aws_subnet" "web-pub" {
  vpc_id            = aws_vpc.web-vpc.id
  cidr_block        = "10.10.254.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name        = "development-web-pub"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

resource "aws_internet_gateway" "web-igw" {
  vpc_id = aws_vpc.web-vpc.id

  tags = {
    Name        = "development-web-igw"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

resource "aws_route_table" "web-pub" {
  vpc_id = aws_vpc.web-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.web-igw.id
  }

  tags = {
    Name        = "development-web-pub"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

resource "aws_route_table_association" "web-pub" {
  subnet_id      = aws_subnet.web-pub.id
  route_table_id = aws_route_table.web-pub.id
}

## INSTANCES

resource "aws_security_group" "web-pub-sg" {
  name        = "development-web-pub-sg"
  description = "Allow TCP inbound traffic for the web-pub subnet"
  vpc_id      = aws_vpc.web-vpc.id

  ingress {
    description = "Allow SSH from MIB network"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["216.5.89.0/24"]
  }

  ingress {
    description = "Allow all HTTP traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description      = "Allow all egress traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name        = "development-web-pub-sg"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

resource "aws_network_interface" "www1-eth0" {
  subnet_id       = aws_subnet.web-pub.id
  private_ips     = ["10.10.254.10"]
  security_groups = [aws_security_group.web-pub-sg.id]

  tags = {
    Name        = "development-www1-eth0"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

# Allocates a new public IP and associates it (NAT) with www1-eth0
resource "aws_eip" "www1-public-ip" {
  network_interface = aws_network_interface.www1-eth0.id
  vpc               = true
  depends_on        = [aws_internet_gateway.web-igw]

  tags = {
    Name        = "development-www1-public-ip"
    Project     = "networking-deep-dive"
    Environment = "development"
  }
}

data "aws_ami" "linux-with-docker" {
  most_recent = true

  filter {
    name   = "name"
    values = ["aws-elasticbeanstalk-amzn-2018.03.0.x86_64-ecs-hvm-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

resource "aws_instance" "www1" {
  ami                    = data.aws_ami.linux-with-docker.id
  instance_type          = "t2.micro"
  #subnet_id              = aws_subnet.web-pub.id
  #vpc_security_group_ids = [aws_security_group.web-pub-sg.id]
  key_name               = "training-key"

  network_interface {
    network_interface_id = aws_network_interface.www1-eth0.id
    device_index         = 0
  }

  tags = {
    Name        = "development-www1"
    Project     = "networking-deep-dive"
    Environment = "development"
  }

}

##################################################################################
# OUTPUTS
##################################################################################

output "www1_public_ip" {
  value = aws_eip.www1-public-ip.public_ip
}
