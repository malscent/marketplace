#!/usr/bin/env bash

set -eu

function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 10 ; echo '')
    echo "${NEW_UUID}"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
STACK_NAME_DEFAULT="cb_test_stack_$(__generate_random_string)"
DEFAULT_REGION=$(aws configure get region)
echo "$DEFAULT_REGION"
if [ -z "$DEFAULT_REGION" ]; then
    REGION="us-east-1"
fi
SERVER_INSTANCE_COUNT_DEFAULT=$(jq '.Parameters.ServerInstanceCount.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)
SERVER_VERSION_DEFAULT=$(jq '.Parameters.ServerVersion.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)

while getopts n:c:v:k:r:u:p: flag
do
    case "${flag}" in
        n) STACK_NAME=${OPTARG};;
        c) SERVER_INSTANCE_COUNT=${OPTARG};;
        v) SERVER_VERSION=${OPTARG};;
        k) KEY_NAME=${OPTARG};;
        r) REGION=${OPTARG};;
        u) USERNAME=${OPTARG};;
        p) PASSWORD=${OPTARG};;
        *) exit 1;;
    esac
done

REGION=${REGION:-$DEFAULT_REGION}
STACK_NAME=${STACK_NAME:-$STACK_NAME_DEFAULT}
SERVER_INSTANCE_COUNT=${SERVER_INSTANCE_COUNT:-$SERVER_INSTANCE_COUNT_DEFAULT}
SERVER_VERSION=${SERVER_VERSION:-$SERVER_VERSION_DEFAULT}
KEY_NAME=${KEY_NAME:-"couchbase-${REGION}"}
USERNAME=${USERNAME:-"couchbase"}
PASSWORD=${PASSWORD:-"foo123!"}


${SCRIPT_DIR}/../makeArchives.sh -m "${SCRIPT_DIR}/mappings.json" \
                                 -s "${SCRIPT_DIR}/embedded_server.sh" \
                                 -o "${SCRIPT_DIR}/../../build/aws/CouchbaseServer/" \
                                 -n "aws-cb-server.template" \
                                 -i "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" \
                                 -t "server"

TEMPLATE_BODY="file://${SCRIPT_DIR}/../../build/aws/CouchbaseServer/aws-cb-server.template"
echo "$TEMPLATE_BODY"
#TEMPLATE_BODY="file://couchbase-$2.template"

SSHCIDR="0.0.0.0/0"

echo "Instance Count: $SERVER_INSTANCE_COUNT"
echo "Default: $SERVER_INSTANCE_COUNT_DEFAULT"
echo "GatewayVersion: $SERVER_VERSION"
echo "Default: $SERVER_VERSION_DEFAULT"

VPC_NAME=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=true" | jq -r '.Vpcs[].VpcId')
#VpcName=vpc-0c1cd329084365f10
SUBNET_ID=$(aws ec2 describe-subnets --filter "Name=vpc-id,Values=${VPC_NAME}" --max-items 1 --region "$REGION" | jq -r '.Subnets[].SubnetId')
#SubnetId=subnet-08476a90d895839b4

aws cloudformation create-stack \
--disable-rollback \
--capabilities CAPABILITY_IAM \
--template-body "${TEMPLATE_BODY}" \
--stack-name "${STACK_NAME}" \
--region "${REGION}" \
--parameters \
ParameterKey=Username,ParameterValue="${USERNAME}" \
ParameterKey=Password,ParameterValue="${PASSWORD}" \
ParameterKey=KeyName,ParameterValue="${KEY_NAME}" \
ParameterKey=SSHCIDR,ParameterValue=${SSHCIDR} \
ParameterKey=ServerInstanceCount,ParameterValue="${SERVER_INSTANCE_COUNT}" \
ParameterKey=ServerVersion,ParameterValue="${SERVER_VERSION}" \
ParameterKey=VpcName,ParameterValue="${VPC_NAME}" \
ParameterKey=SubnetList,ParameterValue="${SUBNET_ID}"


OUTPUT=$(aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "CREATE_COMPLETE"  or .ResourceStatus == "ROLLBACK_COMPLETE") | .ResourceStatus ')
COUNTER=0

printf "Waiting on Stack Creation to Complete ..."
while [[ $OUTPUT != '"CREATE_COMPLETE"' && $OUTPUT != '"ROLLBACK_COMPLETE"' && $COUNTER -le 50 ]]
do
    printf "."
    OUTPUT=$(aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "CREATE_COMPLETE"  or .ResourceStatus == "ROLLBACK_COMPLETE") | .ResourceStatus ')
    (( COUNTER += 1 ))
    sleep 10
done

if [[ $OUTPUT == '"CREATE_COMPLETE"' ]]; then
    printf "Complete!\n"
    exit 0
fi

if [[ $OUTPUT == '"ROLLBACK_COMPLETE"' || $COUNTER -ge 50 ]]; then
    printf "Failed!\n"
    exit 1
fi
