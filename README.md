# Terraform setup for AWS 

Install aws-cli from [AWS](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)  

create your aws keypair pem file 

```
aws ec2 create-key-pair --key-name my-keypair --query 'KeyMaterial' --output text > ~/.ssh/my-keypair.pem

##set permission so no one can read 
chmod 400 ~/.ssh/my-keypair.pem

```

apply the key to your config 

```
  key_name               = "my-keypair"
```

## Launch Instance 

This code launches micro instance. If you need another type of instance find the AMI and instance type from AWS console. 
```
# EC2 Instance (update your resource to use subnet and security group)
resource "aws_instance" "app_server" {
  ami                    = "ami-020cba7c55df1f615"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
  key_name               = "aws-keypair"

  iam_instance_profile   = aws_iam_instance_profile.ec2_instance_profile.name

  tags = {
    Name = "MicroInstance"
  }
}

```
`terraform apply` to launches the instance

`terraform destroy` destroys the instance 


1. If something doesnt work 

```
terraform refresh

terraform destroy
``` 

2. check if key pair is in the correct region

```
aws ec2 describe-key-pairs --region <us-east-1> --key-names aws-keypair 
```
If it doesnt make the key pair in the correct region

```
   aws ec2 create-key-pair --region ap-south-1 --key-name aws-keypair --query 'KeyMaterial' --output text > ~/.ssh/aws-keypair.pem
   chmod 400 ~/.ssh/aws-keypair.pem
```

## SSH into instance
Use your keypair generated in the previous step to ssh into the instance
```
ssh -i ~/.ssh/aws-keypair.pem -X ubuntu@<ip-address>
```

## Writing to the S3 bucket 
```
 import boto3
 from boto3.s3.transfer import TransferConfig
 s3 = boto3.client('s3') 
 s3.upload_file("/home/ubuntu/testfile.txt", "pr-checkpoints" , "testfile.txt")
 ````

```
####delete the file
 response = s3.delete_object(
     Bucket='pr-checkpoints',
     Key='testfile.txt')
```

## Find AMI from AWS-cli 

```
aws ec2 describe-images \
  --region ap-south-1 \
  --owners amazon \
  --filters "Name=name,Values=*Deep Learning*" "Name=state,Values=available" \
  --query 'Images[*].[ImageId,Name]' \
  --output table 
  ```


## Modify Volume Size on Running Instance 
Get volume id from `https://ap-south-1.console.aws.amazon.com/ec2/home?region=ap-south-1#Volumes:` 

```
aws ec2 modify-volume --volume-id vol-xxxxxxxx --size <NEW_SIZE_IN_GB>
```



## User Login Procedure 
-Ask Admin to create AWS Access Key from the IAM->users->access key get 

- Make the key read only 

```
chmod 400 <path_to_aws_private_key>
```
 
- Send the public key to the AWS instance 

```
    aws ec2-instance-connect send-ssh-public-key \

    --instance-id <instance_id>  \

    --availability-zone ap-south-1a \ 

    --instance-os-user ubuntu \

    --ssh-public-key <your_public_awskey>
``` 
 
- Login with the key - Root use

```
ssh ubuntu@<public_ip> -i <path_to_aws_private_key>
``` 

## Tips:
0. **Add to your bashrc (after you connect the EBS instance)**

```

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/mnt/data/miniconda/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/mnt/data/miniconda/etc/profile.d/conda.sh" ]; then
        . "/mnt/data/miniconda/etc/profile.d/conda.sh"
    else
        export PATH="/mnt/data/miniconda/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

```

1. Always switch to the storage provided by the EC2 Instance provide conda prefix 
`conda create --prefix /your/custom/path/myenv python=3.10` 

2. Change conda cache dir 
```
touch ~/.condarc

vim ~/.condarc

pkgs_dirs:
  - /opt/conda_cache  # or another fast drive

```

3. Install nvtop 

```
sudo add-apt-repository ppa:quentiumyt/nvtop
sudo apt install nvtop
```

4. AWS IAM User Management for EC2 access 
 - Create a new user by navigating into AWS Console with root account 
 - Assign the InternEC2 policy 

 ```
 {
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:SendCommand",
                "ssm:StartSession",
                "ssm:TerminateSession",
                "ssm:GetCommandInvocation",
                "ssm:DescribeInstanceInformation",
                "ec2:DescribeInstances"
            ],
            "Resource": "*"
        }
    ]
}

```
 - Assign s3 bucket access policy  
```
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EnableS3access",
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
```
 - In main.tf to allow ssh with public key access add for each user 

 ```
 resource "aws_iam_policy" "ec2_instance_connect" {
  name        = "EC2InstanceConnectPolicy"
  description = "Allow EC2 Instance Connect for a specific user"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "ec2-instance-connect:SendSSHPublicKey",
        Resource = "arn:aws:ec2:ap-south-1:<arn_user_id>:instance/${aws_instance.app_server.id}",
        Condition = {
          StringEquals = {
            "ec2:osuser" = "ubuntu"
          }
        }
      }
    ]
  })
}
```

```
resource "aws_iam_user_policy_attachment" "attach_ec2_instance_connect" {
  user       = "<arn_username>" # Replace with your IAM user name
  policy_arn = aws_iam_policy.ec2_instance_connect.arn
}
```


5. OneDrive direct download 

- Upload a file to OneDrive and after setting the access to public you can download it with appending `&download=1` 

- Download on AWS EC2 Instance with: 

```
wget --content-disposition --trust-server-names --max-redirect=50 -O <filename>.<ext> \
"<link>?download=1"
```

6. Attach EBS Volume to the EC2 Instance device has been (500GB has been formatted to ext4 before DO NOT REFORMAT IT WILL ERASE THE DATA) 

```
sudo mkdir -p /mnt/data
sudo mount /dev/xvdf /mnt/data
```

7. Edit terraform state to remove persistent storage from destory plan 

```
terraform state rm aws_ebs_volume.persistent_data
terraform state rm aws_volume_attachment.app_server_data
```

or target to destroy 


```
terraform destroy -target=aws_instance.app_server -target=aws_security_group.allow_ssh -target=aws_internet_gateway.gw ...
`` 

8. Copying data to the instance with key example: 

```rsync -chavzP --stats -e "ssh -i ~/.ssh/apsouthkey.pem" franka_recordings/ ubuntu@65.0.74.61:/mnt/data/``

9. Spot Instance creation: 
Include spot in the `instance_market_options`  

```
  instance_market_options {
    market_type = "spot"
  }
``` 
