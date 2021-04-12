#!/bin/bash

set -eu 

###############################################################################
# Dependencies:                                                               #
# gcloud                                                                      #
# tr                                                                          #
###############################################################################
#  Builds a blank AMI for usage in marketplace.  Base image is based off a    #
#  m4.xlarge AWS EC2 instance                                                 #
#                                                                             #
# NOTE:  This script requires an AWS Security Group created on the default    #
# VPC.  It must be named 'aws-ami-creation' and allow ingress and egress of   #
# http, https and ssh traffic                                                 #
###############################################################################
#  Parameters                                                                 #
#  -r : region                                                                #
#     usage:  -n us-east-1                                                    #
#     purpose:  The region you want the base instance to be created in        #
#  -n : AMI Name                                                              #
#     usage: -n ja-test-ami                                                   #
#     purpose: specifies the name of the AMI to create                        #
###############################################################################

function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 10 ; echo '')
    echo "${NEW_UUID}"
}

#Constants
INSTANCE_TYPE=m4.xlarge
SECURITY_GROUP=aws-ami-creation

while getopts r:n: flag
do
    case "${flag}" in
        r) REGION=${OPTARG};;
        n) AMI_NAME=${OPTARG};;
        *) exit 1;;
    esac
done

# Create Output Folder
SCRIPT_SOURCE=${BASH_SOURCE[0]/%create.sh/}
mkdir -p "$SCRIPT_SOURCE../../build/aws/couchbase-ami-creation/"

#Get AMI from AWS for the approved instance type
BASE_AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --region "$REGION" | jq -r '.Parameters[] | .Value')
echo "Base AMI:  $BASE_AMI_ID"

#Generate a SSH key for ssh into instance
KEY_NAME="ami-creation-$(__generate_random_string)"
echo "Key Name to be created: $KEY_NAME"
mkdir -p "$HOME/.ssh" 2>&1
rm -rf "$HOME/.ssh/aws-keypair.pem" 2>&1
aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$HOME/.ssh/aws-keypair.pem"
chmod 400 "$HOME/.ssh/aws-keypair.pem"
echo "$KEY_NAME Created."

# Create an instance to base our image off of.
echo "Running Instance."
AWS_RESPONSE=$(aws ec2 run-instances \
    --image-id "$BASE_AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --security-groups "$SECURITY_GROUP" \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --output json)

INSTANCE_ID=$(echo "$AWS_RESPONSE" | jq -r '.Instances[] | .InstanceId')
echo "Instance Id: $INSTANCE_ID"
PUBLIC_IP=$(aws ec2 describe-instances --instance-id "$INSTANCE_ID" | jq -r '.Reservations[] | .Instances[] | .NetworkInterfaces[] | .Association.PublicIp')
echo "Instance Public IP: $PUBLIC_IP"

# If we decide to do more than just an empty OS. We need to do it before we run this command, as you won't be able to log into the VM once we're done
# This ssh's into the instance updates the packages and removes ec2-user and root ssh details
echo "Waiting on instance to intialize"
instanceState=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json | jq -r '.Reservations[] | .Instances[] | .State.Name')

until [[ "$instanceState" == "running" ]]; do
    sleep 5
    instanceState=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json | jq -r '.Reservations[] | .Instances[] | .State.Name')
done

echo "Updating packages on instance"
ssh -i "$HOME/.ssh/aws-keypair.pem" -o StrictHostKeyChecking=no "ec2-user@$PUBLIC_IP" "sudo yum update -y && echo 'Removing Ec2-User Authorized Keys' && rm -rf /home/ec2-user/.ssh/* && echo 'Removing root Authorized Keys' && rm -rf /home/root/.ssh/*"


#Create AMI
echo "Creating AMI:  $AMI_NAME"
todaysDate=$(date '+%Y-%m-%d %T')
imageResponse=$(aws ec2 create-image \
  --instance-id "$INSTANCE_ID" \
  --name "$AMI_NAME" \
  --description "Auto-generated AMI for Couchbase on $todaysDate" \
  --output json)

AMI_ID=$(echo "$imageResponse" | jq -r '.ImageId')

#AMI is in pending.. so we cannot clean up until it is "available", then we can terminate the instance
STATUS=$(aws ec2 describe-images --image-id "$AMI_ID" | jq -r '.Images[] | .State')
echo -n "$AMI_ID created, waiting on available..."
until [[ "$STATUS" == "available" ]]; do
    sleep 10
    STATUS=$(aws ec2 describe-images --image-id "$AMI_ID" | jq -r '.Images[] | .State')
    echo -n "."
done
echo "Available!"

#Write out to the build folder the AMI details
jq -n --arg id "$AMI_ID" --arg name "$AMI_NAME" '{"id":$id, "name":$name}' > "$SCRIPT_SOURCE../../build/aws/couchbase-ami-creation/$AMI_NAME.json"
#CLEANUP!
echo "Cleaning up created resources"
echo "Deleting $KEY_NAME"
aws ec2 delete-key-pair --key-name "$KEY_NAME"
rm -rf "$HOME/.ssh/aws-keypair.pem"
echo "Deleting instance: $INSTANCE_ID"
aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"