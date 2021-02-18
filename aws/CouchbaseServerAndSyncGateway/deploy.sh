#!/usr/bin/env bash
SCRIPT_SOURCE=${BASH_SOURCE[0]/%deploy.sh/}

STACK_NAME=$1
PRICING_TYPE=$2 #byol or hourlypricing
TEMPLATE_BODY="file://${SCRIPT_SOURCE}couchbase-$2-amzn-lnx2.template"
echo "$TEMPLATE_BODY"
#TEMPLATE_BODY="file://couchbase-$2.template"
REGION=`aws configure get region`
echo "$REGION"
if [ -z "$REGION" ]; then
    REGION="us-east-1"
fi
Username="couchbase"
Password="foo123!"
KeyName="couchbase-${REGION}"
SSHCIDR="0.0.0.0/0"

aws cloudformation create-stack \
--capabilities CAPABILITY_IAM \
--template-body "${TEMPLATE_BODY}" \
--stack-name "${STACK_NAME}" \
--region "${REGION}" \
--parameters \
ParameterKey=Username,ParameterValue=${Username} \
ParameterKey=Password,ParameterValue=${Password} \
ParameterKey=KeyName,ParameterValue="${KeyName}" \
ParameterKey=SSHCIDR,ParameterValue=${SSHCIDR}


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
