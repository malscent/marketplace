#!/usr/bin/env bash

set -eu

function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 10 ; echo '')
    echo "${NEW_UUID}"
}

REGION="us-east-1"
INSTANCE_TYPE=m4.xlarge

while getopts r:t:i: flag
do
    case "${flag}" in
        r) REGION=${OPTARG};;
        t) TAG=${OPTARG};;
        i) INSTANCE_TYPE=${OPTARG};;
        *) exit 1;;
    esac
done

BASE_AMI_ID=$(jq --arg region "$REGION" -r '.CouchbaseServer[$region].AMI' ../CouchbaseServer/mappings.json)

#Generate a SSH key for ssh into instance
KEY_NAME="ami-creation-$(__generate_random_string)"
mkdir -p "$HOME/.ssh" 2>&1
rm -rf "$HOME/.ssh/aws-keypair.pem" 2>&1
aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > "$HOME/.ssh/aws-keypair.pem"
chmod 400 "$HOME/.ssh/aws-keypair.pem"

SECURITY_GROUP=aws-ami-creation

SERVER_STARTUP=$(base64 ./server_user_data.sh)

AWS_RESPONSE=$(aws ec2 run-instances \
    --image-id "$BASE_AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --security-groups "$SECURITY_GROUP" \
    --key-name "$KEY_NAME" \
    --region "$REGION" \
    --user-data "$SERVER_STARTUP" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=identifier,Value=$TAG}]" \
    --block-device-mappings "DeviceName=/dev/sdk,Ebs={DeleteOnTermination=true,VolumeSize=100,VolumeType=gp3}" \
    --output json)

INSTANCE_ID=$(echo "$AWS_RESPONSE" | jq -r '.Instances[] | .InstanceId')
PUBLIC_IP=$(aws ec2 describe-instances --instance-id "$INSTANCE_ID" | jq -r '.Reservations[] | .Instances[] | .NetworkInterfaces[] | .Association.PublicIp')
echo "$PUBLIC_IP"
instanceState=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json | jq -r '.Reservations[] | .Instances[] | .State.Name')

until [[ "$instanceState" == "running" ]]; do
    sleep 5
    instanceState=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --output json | jq -r '.Reservations[] | .Instances[] | .State.Name')
done
sleep 60

