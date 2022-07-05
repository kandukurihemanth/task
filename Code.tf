# For Provider
provider "aws" {
  region     = var.AWS_REGION
  access_key = "AKIAQ3SN3UXF3M6WBEMA"
  secret_key = "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"
 }

# For VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  enable_classiclink   = "false"
  tags = {
    Name = "main"
  }
}

# For Subnets
resource "aws_subnet" "main-public-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1a"
  tags = {
    Name = "main-public-1"
  }
}

resource "aws_subnet" "main-private-1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1b"
  tags = {
    Name = "main-private-1"
  }
}
resource "aws_subnet" "main-public-2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1c"
  tags = {
    Name = "main-public-2"
  }
}

# For Internet Gateway
resource "aws_internet_gateway" "main-gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main_igw"
  }
}

# For Route Tables
resource "aws_route_table" "main-public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main-gw.id
  }
  tags = {
    Name = "main-public-1_RT"
  }
}

# For Route associations public
resource "aws_route_table_association" "main-public-1-a" {
  subnet_id      = aws_subnet.main-public-1.id
  route_table_id = aws_route_table.main-public.id
}
resource "aws_route_table_association" "main-public-2-a" {
  subnet_id      = aws_subnet.main-public-2.id
  route_table_id = aws_route_table.main-public.id
}


resource "aws_key_pair" "mykeypair" {
  key_name   = "mykeypair"
  public_key = file(var.PATH_TO_PUBLIC_KEY)
}

variable "AWS_REGION" {
  default = "eu-west-1"
}
variable "PATH_TO_PRIVATE_KEY" {
  default = "mykey"
}
variable "PATH_TO_PUBLIC_KEY" {
  default = "mykey.pub"
}

resource "aws_lb_target_group" "test" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "test" {
  target_group_arn = aws_lb_target_group.test.arn
  target_id        = aws_instance.example_2.id
  port             = 80
}
resource "aws_security_group" "allow-ssh" {
  vpc_id      = aws_vpc.main.id
  name        = "Hemanth-sg"
  description = "security group that allows ssh & http and all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Hemanth-allow-ssh"
  }
}

resource "aws_instance" "example" {
  ami           = "ami-00c90dbdc12232b58"
  instance_type = "t2.micro"
  # the VPC subnet
  subnet_id = aws_subnet.main-public-1.id
  # the security group
  vpc_security_group_ids = [aws_security_group.allow-ssh.id]
  # the public SSH key
  key_name = aws_key_pair.mykeypair.key_name
  tags = {
    Name = "Hemanth-ec2"
  }
}

resource "aws_security_group" "allow-ssh2" {
  vpc_id      = aws_vpc.main.id
  name        = "Hemanth-sg2"
  description = "Private security group that allows ssh and all egress traffic"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${aws_instance.example.private_ip}/32"]
  }

 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
     security_groups = [aws_security_group.allow-ssh.id]
  }
  tags = {
    Name = "Hemanth-allow-ssh2"
  }
}

resource "aws_instance" "example_2" {
  ami           = "ami-00c90dbdc12232b58"
  instance_type = "t2.micro"
  # the VPC subnet
  subnet_id                   = aws_subnet.main-private-1.id
  associate_public_ip_address = "false"
  # the security group
  vpc_security_group_ids = [aws_security_group.allow-ssh2.id]
  # the public SSH key
  key_name = aws_key_pair.mykeypair.key_name

  user_data = <<-EOF
  #!/bin/bash
  echo "*** Installing apache2"
  sudo apt update -y
  sudo apt install apache2 -y
  echo "*** Completed Installing apache2"
  sudo systemctl start apache2.service

  EOF

  tags = {
    Name = "Hemanth-private-ec2"
  }
}

# For NAT Gateway
resource "aws_eip" "nat" {
  vpc = true
}

resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.main-public-1.id
  depends_on    = [aws_internet_gateway.main-gw]
}

# For Route Table
resource "aws_route_table" "main-private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }
  tags = {
    Name = "main-private-1_RT"
  }
}

# For Route associations private
resource "aws_route_table_association" "main-private-1-a" {
  subnet_id      = aws_subnet.main-private-1.id
  route_table_id = aws_route_table.main-private.id
}

resource "aws_lb" "demo_alb" {
    name               = "demo-alb"
    internal           = false
    load_balancer_type = "application"
    security_groups    = [aws_security_group.allow-ssh2.id, aws_security_group.allow-ssh.id]
    subnets            = [aws_subnet.main-public-1.id, aws_subnet.main-private-1.id ]
    enable_cross_zone_load_balancing = "true"
    tags = {
        Name = "demo-alb"
    }
}

resource "aws_lb_listener" "lb_listener_http" {
   load_balancer_arn    = aws_lb.demo_alb.id
   port                 = "80"
   protocol             = "HTTP"
   default_action {
    target_group_arn = aws_lb_target_group.test.id
    type             = "forward"
  }
}
