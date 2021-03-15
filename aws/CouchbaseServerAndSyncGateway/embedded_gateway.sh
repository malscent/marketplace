#!/usr/bin/env bash
echo 'Running startup script...'

#These values will be replaced with appropriate values during compilation into the Cloud Formation Template
#To run directly, simply set values prior to executing script.  Any variable with $__ prefix and __ suffix will
#get replaced during compliation

# shellcheck disable=SC2154
VERSION=$__SyncGatewayVersion__
# shellcheck disable=SC2154
stackName=$__AWSStackName__
# shellcheck disable=SC2154
USERNAME=$__Username__
# shellcheck disable=SC2154
PASSWORD=$__Password__

region=$(ec2-metadata -z | cut -d " " -f 2 | sed 's/.$//')
instanceId=$(ec2-metadata -i | cut -d " " -f 2)
echo "Using the settings:"
echo "stackName '$stackName'"
echo "region '$region'"
echo "instanceID '$instanceId'"
aws ec2 create-tags \
  --region "${region}" \
  --resources "${instanceId}" \
  --tags Key=Name,Value="${stackName}-SyncGateway"

CLUSTER_HOST=$(curl -s  http://169.254.169.254/latest/meta-data/public-hostname)

if [[ ! -e "couchbase_installer.sh" ]]; then
    curl -L --output "couchbase_installer.sh" "https://github.com/couchbase-partners/marketplace-scripts/releases/download/v1.0.4/couchbase_installer.sh"
fi

bash ./couchbase_installer.sh -ch "$CLUSTER_HOST" -u "$USERNAME" -p "$PASSWORD" -v "$VERSION" -os AMAZON -e AWS -c -d -g