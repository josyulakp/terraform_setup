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

`terraform apply` to launches the instance

`terraform destroy` destroys the instance 


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

