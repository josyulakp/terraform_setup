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


## Tips:

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