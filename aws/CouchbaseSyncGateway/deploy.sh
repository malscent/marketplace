#!/usr/bin/env bash

set -eu

function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 10 ; echo '')
    echo "${NEW_UUID}"
}

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

STACK_NAME_DEFAULT="cb_test_stack_$(__generate_random_string)"
SyncGatewayInstanceCountDefault=$(jq '.Parameters.SyncGatewayInstanceCount.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)
SyncGatewayVersionDefault=$(jq '.Parameters.SyncGatewayVersion.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)
DefaultRegion=$(aws configure get region)
KeyNameDefault="couchbase-${DefaultRegion}"

while getopts n:c:v:u:b:d:k:r: flag
do
    case "${flag}" in
        n) STACK_NAME=${OPTARG:-$STACK_NAME_DEFAULT};;
        c) SyncGatewayInstanceCount=${OPTARG:-$SyncGatewayInstanceCountDefault};;
        v) SyncGatewayVersion=${OPTARG};;
        u) CouchbaseClusterURL=${OPTARG};;
        b) BucketName=${OPTARG};;
        d) DatabaseName=${OPTARG};;
        k) KeyName=${OPTARG};;
        r) REGION=${OPTARG};;
        *) exit 1;;
    esac
done

STACK_NAME=${STACK_NAME:-$STACK_NAME_DEFAULT}
SyncGatewayInstanceCount=${SyncGatewayInstanceCount:-$SyncGatewayInstanceCountDefault}
SyncGatewayVersion=${SyncGatewayVersion:-$SyncGatewayVersionDefault}
REGION=${REGION:-$DefaultRegion}
KeyName=${KeyName:-$KeyNameDefault}

echo "Before Make Archives : $SCRIPT_DIR"
${SCRIPT_DIR}/../makeArchives.sh -m "${SCRIPT_DIR}/mappings.json" \
                                 -s "${SCRIPT_DIR}/embedded_gateway.sh" \
                                 -o "${SCRIPT_DIR}/../../build/aws/CouchbaseSyncGateway/" \
                                 -n "aws-cb-syncgateway.template" \
                                 -i "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" \
                                 -t "sync_gateway"
TEMPLATE_BODY="file://${SCRIPT_DIR}/../../build/aws/CouchbaseSyncGateway/aws-cb-syncgateway.template"
echo "$TEMPLATE_BODY"
#TEMPLATE_BODY="file://couchbase-$2.template"
echo "$REGION"
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
Username="couchbase"
Password="foo123!"

#KeyName="ja-test-kp"
SSHCIDR="0.0.0.0/0"

echo "Instance Count: $SyncGatewayInstanceCount"
echo "Default: $SyncGatewayInstanceCountDefault"

echo "GatewayVersion: $SyncGatewayVersion"
echo "Default: $SyncGatewayVersionDefault"

VpcName=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=true" | jq -r '.Vpcs[].VpcId')
#VpcName=vpc-0c1cd329084365f10
SubnetId=$(aws ec2 describe-subnets --filter "Name=vpc-id,Values=${VpcName}" --max-items 1 --region "$REGION" | jq -r '.Subnets[].SubnetId')
#SubnetId=subnet-08476a90d895839b4

aws cloudformation create-stack \
--capabilities CAPABILITY_IAM \
--disable-rollback \
--template-body "${TEMPLATE_BODY}" \
--stack-name "${STACK_NAME}" \
--region "${REGION}" \
--parameters \
ParameterKey=Username,ParameterValue=${Username} \
ParameterKey=Password,ParameterValue=${Password} \
ParameterKey=KeyName,ParameterValue="${KeyName}" \
ParameterKey=SSHCIDR,ParameterValue=${SSHCIDR} \
ParameterKey=SyncGatewayInstanceCount,ParameterValue="${SyncGatewayInstanceCount}" \
ParameterKey=SyncGatewayVersion,ParameterValue="${SyncGatewayVersion}" \
ParameterKey=VpcName,ParameterValue="${VpcName}" \
ParameterKey=SubnetList,ParameterValue="${SubnetId}" \
ParameterKey=CouchbaseClusterUrl,ParameterValue="$CouchbaseClusterURL" \
ParameterKey=Bucket,ParameterValue="$BucketName" \
ParameterKey=DatabaseName,ParameterValue="$DatabaseName" 


Output=$(aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "CREATE_COMPLETE"  or .ResourceStatus == "ROLLBACK_COMPLETE") | .ResourceStatus ')
Counter=0

printf "Waiting on Stack Creation to Complete ..."
while [[ $Output != '"CREATE_COMPLETE"' && $Output != '"ROLLBACK_COMPLETE"' && $Counter -le 50 ]]
do
    printf "."
    Output=$(aws cloudformation describe-stack-events --stack-name "${STACK_NAME}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "CREATE_COMPLETE"  or .ResourceStatus == "ROLLBACK_COMPLETE") | .ResourceStatus ')
    (( Counter += 1 ))
    sleep 10
done

if [[ $Output == '"CREATE_COMPLETE"' ]]; then
    printf "Complete!\n"
    exit 0
fi

if [[ $Output == '"ROLLBACK_COMPLETE"' || $Counter -ge 50 ]]; then
    printf "Failed!\n"
    exit 1
fi
