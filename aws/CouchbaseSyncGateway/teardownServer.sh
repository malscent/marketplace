#!/usr/bin/env bash

while getopts t: flag
do
    case "${flag}" in
        t) TAG=${OPTARG};;
        *) exit 1;;
    esac
done

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:identifier,Values=$TAG" | jq '.Reservations[] | .Instances[] | select( .State.Name == "running") | .InstanceId' -r) || INSTANCE_ID=""

if [[ -n "$INSTANCE_ID" ]]; then
    aws ec2 terminate-instances --instance-ids "$INSTANCE_ID"
else
    echo "No instances to terminate."
fi