# Provider Info 

provider "aws" {
    profile = "default" 
    region = "ap-south-1" 
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

# Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
}

# Data source to get the caller's identity (includes account ID)
data "aws_caller_identity" "current" {}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Associate Route Table with Subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.rt.id
}

# Security Group
resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Restrict in production!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role
resource "aws_iam_role" "ec2_role" {
  name = "ec2_s3_access_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Sid    = "AllowEC2ToAssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Sid    = "AllowUserToAssumeRole",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/KrishnaJosyula"
        }
      }
    ]
  })
}

# Attach S3 access policy (full access)
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Instance Profile
resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "ec2_instance_profile"
  role = aws_iam_role.ec2_role.name
}

###useful AMIs
##L40 old: "ami-0140f55e7363d9486" # t2micro "ami-021a584b49225376d" DL-Ubuntu22.04: "ami-0bdea0bb64cf0f044"
## EC2 Instance (update your resource to use subnet and security group)

resource "aws_instance" "app_server" {
  ami                    = "ami-021a584b49225376d" 
  instance_type          = "t2.micro" #"g6.xlarge"  # 
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name               = "apsouthkey"

  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name


  root_block_device {
    volume_size = 100  # Size in GB
    volume_type = "gp3"
    delete_on_termination = true
  }

  tags = {
    Name = "L40Instance"
  }
}

resource "aws_iam_policy" "ec2_instance_connect" {
  name        = "EC2InstanceConnectPolicy"
  description = "Allow EC2 Instance Connect for a specific user"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ec2-instance-connect:SendSSHPublicKey",
        Resource = "arn:aws:ec2:ap-south-1:145216744769:instance/${aws_instance.app_server.id}",
        Condition = {
          StringEquals = {
            "ec2:osuser" = "ubuntu"
          }
        }
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "attach_ec2_instance_connect" {
  user       = "JeeveshM" # Replace with your IAM user name
  policy_arn = aws_iam_policy.ec2_instance_connect.arn
}

# Persistent EBS Volume
resource "aws_ebs_volume" "persistent_data" {
  availability_zone = aws_subnet.main.availability_zone
  size              = 500 # Size in GB, adjust as needed
  type              = "gp3"
  tags = {
    Name = "PersistentDataVolume"
  }
}

#Attach EBS Volume to the EC2 Instance device has been formatted to ext4
#sudo mkdir -p /mnt/data
#sudo mount /dev/xvdf /mnt/data
resource "aws_volume_attachment" "app_server_data" {
  device_name = "/dev/xvdf"
  volume_id   = aws_ebs_volume.persistent_data.id
  instance_id = aws_instance.app_server.id
  force_detach = true
}


output "instance_public_ip" {
  description = "The public IP address of the EC2 instance."
  value       = aws_instance.app_server.public_ip
}

output "instance_id"{ 
  description = "Instance id of the EC2 instance" 
  value = aws_instance.app_server.id
}

# Example: Attach the same EBS volume to another instance (uncomment and use as needed)
# resource "aws_instance" "app_server2" {
#   ami                    = "ami-0140f55e7363d9486"
#   instance_type          = "t2.micro"
#   subnet_id              = aws_subnet.main.id
#   vpc_security_group_ids = [aws_security_group.allow_ssh.id]
#   key_name               = "aws-keypair"
#   iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name
#   tags = {
#     Name = "SecondInstance"
#   }
# }
#
# resource "aws_volume_attachment" "app_server2_data" {
#   device_name = "/dev/xvdf"
#   volume_id   = aws_ebs_volume.persistent_data.id
#   instance_id = aws_instance.app_server2.id
#   force_detach = true
# }