#!/usr/bin/env bash

STACK_NAME=$1
STACK_ID=$(aws cloudformation describe-stacks | jq -r '.Stacks[] | select(.StackName == "'${STACK_NAME}'") | .StackId')
aws cloudformation delete-stack --stack-name "$STACK_ID"

Output=$(aws cloudformation describe-stack-events --stack-name "${STACK_ID}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "DELETE_COMPLETE") | .ResourceStatus ')
Counter=0

printf "Waiting on Stack Deletion to Complete ..."
while [[ $Output != '"DELETE_COMPLETE"' && $Counter -le 50 ]]
do
    printf "."
    Output=$(aws cloudformation describe-stack-events --stack-name "${STACK_ID}" | jq '.StackEvents[] | select(.ResourceType == "AWS::CloudFormation::Stack") | . | select(.ResourceStatus == "DELETE_COMPLETE") | .ResourceStatus ')
    (( Counter += 1 ))
    sleep 10
done

if [[ $Output == '"DELETE_COMPLETE"' ]]; then
    printf "Complete!\n"
    exit 0
fi

if [[ $Counter -ge 50 ]]; then
    printf "Failed!\n"
    exit 1
fi