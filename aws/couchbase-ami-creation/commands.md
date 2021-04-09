# Create instance


```
BASE_AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --region $REGION | jq -r '.Parameters[] | .Value')
INSTANCE_TYPE=m4.xlarge
SECURITY_GROUP=default

aws ec2 run-instances \
    --image-id $BASE_AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-groups $SECURITY_GROUP \
    --key-name $KEY_NAME \
    --region $REGION
```