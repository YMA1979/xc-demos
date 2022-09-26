#Configure the AWS provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region  = "eu-west-1"
  shared_credentials_files = ["/Users/stobrien/.aws/credentials"]
  profile = "default"
}

#Configure the VPC and Public Subnets
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"

  name = "${var.prefix}-f5-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-west-1a"]
  public_subnets  = ["10.0.1.0/24"]
  private_subnets = ["10.0.2.0/24"]

  enable_nat_gateway = true

  tags = {
    Terraform = true
    Environment = "ob1-vpc-teraform"
  }
}

#Configure the security Group for management and application access
resource "aws_security_group" "f5" {
  name   = "${var.prefix}-f5"
  vpc_id = module.vpc.vpc_id

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

    ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

   ingress {
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
     cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "ob1-SecurityGroup1"
  }
}

#Reference the template file that will be used to configure the Juice Shop application
data "template_file" "user_data" {
  template = file("${path.module}/userdata.tmpl")

}

#Build the EC2 instance and install Apache
resource "aws_instance" "Apache" {
  ami = "ami-09e2d756e7d78558d"
  instance_type = "t2.micro"
  subnet_id   = module.vpc.public_subnets[0]
  private_ip = "10.0.1.10"
  #subnet_id   = module.vpc.private_subnets[0]
  #private_ip = "10.0.2.10"
  key_name   = var.ssh_key_name
  user_data = data.template_file.user_data.rendered
  security_groups = [ aws_security_group.f5.id ]
    tags = {
    Name = "OB1-ApacheServer-West1"
  }
}