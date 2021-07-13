#!/usr/bin/env bash

set -eu

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
${SCRIPT_DIR}/../makeArchives.sh -m "${SCRIPT_DIR}/mappings.json" \
                                 -s "${SCRIPT_DIR}/embedded_server.sh" \
                                 -o "${SCRIPT_DIR}/../../build/aws/CouchbaseServer/" \
                                 -n "aws-cb-server.template" \
                                 -i "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" \
                                 -t "server"

STACK_NAME=$1
TEMPLATE_BODY="file://${SCRIPT_DIR}/../../build/aws/CouchbaseServer/aws-cb-server.template"
echo "$TEMPLATE_BODY"
#TEMPLATE_BODY="file://couchbase-$2.template"
REGION=$(aws configure get region)
echo "$REGION"
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
Username="couchbase"
Password="foo123!"
KeyName="couchbase-${REGION}"
#KeyName="ja-test-kp"
SSHCIDR="0.0.0.0/0"
ServerInstanceCountDefault=$(jq '.Parameters.ServerInstanceCount.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)
ServerInstanceCount=${2:-$ServerInstanceCountDefault}
echo "Instance Count: $ServerInstanceCount"
echo "Default: $ServerInstanceCountDefault"
ServerVersionDefault=$(jq '.Parameters.ServerVersion.Default' "${SCRIPT_DIR}/couchbase-amzn-lnx2.template" -r)
ServerVersion=${3:-$ServerVersionDefault}
echo "GatewayVersion: $ServerVersion"
echo "Default: $ServerVersionDefault"

VpcName=$(aws ec2 describe-vpcs --filter "Name=isDefault,Values=true" | jq -r '.Vpcs[].VpcId')
#VpcName=vpc-0c1cd329084365f10
SubnetId=$(aws ec2 describe-subnets --filter "Name=vpc-id,Values=${VpcName}" --max-items 1 --region "$REGION" | jq -r '.Subnets[].SubnetId')
#SubnetId=subnet-08476a90d895839b4

aws cloudformation create-stack \
--disable-rollback \
--capabilities CAPABILITY_IAM \
--template-body "${TEMPLATE_BODY}" \
--stack-name "${STACK_NAME}" \
--region "${REGION}" \
--parameters \
ParameterKey=Username,ParameterValue=${Username} \
ParameterKey=Password,ParameterValue=${Password} \
ParameterKey=KeyName,ParameterValue="${KeyName}" \
ParameterKey=SSHCIDR,ParameterValue=${SSHCIDR} \
ParameterKey=ServerInstanceCount,ParameterValue="${ServerInstanceCount}" \
ParameterKey=ServerVersion,ParameterValue="${ServerVersion}" \
ParameterKey=VpcName,ParameterValue="${VpcName}" \
ParameterKey=SubnetList,ParameterValue="${SubnetId}"


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
