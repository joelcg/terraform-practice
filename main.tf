terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# cloud provider

provider "aws" {
  region = "us-east-1"
#  access_key = ""
#  secret_key = ""
}

# vpc

resource "aws_vpc" "vpc-1" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "tf-vpc"
  }
}

# internet gateway

resource "aws_internet_gateway" "gw-1" {
  vpc_id = aws_vpc.vpc-1.id
  tags = {
    Name = "tf-gw"
  }
}

# route table

resource "aws_route_table" "rt-1" {
  vpc_id = aws_vpc.vpc-1.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw-1.id
  }

  route {
    ipv6_cidr_block        = "::/0"
    gateway_id = aws_internet_gateway.gw-1.id
  }

  tags = {
    Name = "tf-rt"
  }
}

# subnet

resource "aws_subnet" "subnet-1" {
  vpc_id     = aws_vpc.vpc-1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  tags = {
    Name = "tf-subnet"
  }
}

# route table association

resource "aws_route_table_association" "rta-1" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt-1.id
}

# security group

resource "aws_security_group" "sg-1" {
  name        = "allow_web_traffic"
  description = "Allow web traffic inbound traffic"
  vpc_id      = aws_vpc.vpc-1.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  
  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# network interface

resource "aws_network_interface" "nic-1" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.sg-1.id]
}

# elastic ip

resource "aws_eip" "ip-1" {
  vpc                       = true
  network_interface         = aws_network_interface.nic-1.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw-1]
}

# web server instance

resource "aws_instance" "ec2-1" {
  ami           = "ami-052efd3df9dad4825"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a"
  key_name = "aws"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.nic-1.id
  }

  tags = {
    Name = "tf-ec2"
  }

  user_data = <<-EOF
                #!/bin/bash
                sudo apt update -y
                sudo apt install apache2 -y
                sudo systemctl start apache2
                sudo bash -c "echo so far so good > /var/www/html/index.html"
                EOF
}

output "server_public_ip" {
    value = aws_instance.ec2-1.public_ip
}
