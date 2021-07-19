#!/usr/bin/env bash
set -ex
echo 'Running startup script...'
# There is a race condition based on when the env vars are set by profile.d and when cloud-init executes
# this just removes that race condition
if [[ -r /etc/profile.d/couchbaseserver.sh ]]; then
   # Disabling lint for unreachable source file
   # shellcheck disable=SC1091
   source /etc/profile.d/couchbaseserver.sh
fi

yum install jq aws-cfn-bootstrap -q -y
#These values will be replaced with appropriate values during compilation into the Cloud Formation Template
#To run directly, simply set values prior to executing script.  Any variable with $__ prefix and __ suffix will
#get replaced during compliation

# shellcheck disable=SC2154
VERSION=$__SyncGatewayVersion__
# shellcheck disable=SC2154
stackName=$__AWSStackName__
# shellcheck disable=SC2154
SECRET=$__CouchbaseSecret__
# shellcheck disable=SC2154
CLUSTER_HOST=$__CouchbaseClusterUrl__
# shellcheck disable=SC2154
DATABASE=$__DatabaseName__
# shellcheck disable=SC2154
BUCKET=$__Bucket__

resource="SyncGatewayAutoScalingGroup"

region=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r '.region')
instanceId=$(ec2-metadata -i | cut -d " " -f 2)

SECRET_VALUE=$(aws secretsmanager get-secret-value --secret-id "${SECRET}" --version-stage AWSCURRENT --region "$region" | jq -r .SecretString)
USERNAME=$(echo "$SECRET_VALUE" | jq -r .username)
PASSWORD=$(echo "$SECRET_VALUE" | jq -r .password)

echo "Using the settings:"
echo "stackName '$stackName'"
echo "region '$region'"
echo "instanceID '$instanceId'"
aws ec2 create-tags \
  --region "${region}" \
  --resources "${instanceId}" \
  --tags Key=Name,Value="${stackName}-SyncGateway"


# __SCRIPT_URL__ gets replaced during build
if [[ ! -e "/setup/couchbase_installer.sh" ]]; then
    curl -L --output "/setup/couchbase_installer.sh" "__SCRIPT_URL__"
fi
SUCCESS=1

if [[ "$COUCHBASE_GATEWAY_VERSION" == "$VERSION" ]]; then
   # expecting this to error if not running.  if we use set -e that will kill the script
   if curl -q http://127.0.0.1:4985/_admin/ &> /dev/null; then
      SUCCESS=0
   else
      nohup /usr/bin/sh /setup/postinstall.sh 0 &> /dev/null &
      nohup /usr/bin/sh /setup/posttransaction.sh &> /dev/null & 
      SUCCESS=$?
      mkdir -p /opt/sync_gateway/etc/
      echo "
{
  \"interface\":\":4984\",
  \"adminInterface\":\"127.0.0.1:4985\",
  \"metricsInterface\":\":4986\",
  \"logging\": {
    \"console\": {
      \"log_keys\": [\"*\"]
    }
  },
  \"databases\": {
    \"$DATABASE\": {
      \"server\": \"$CLUSTER_HOST\",
      \"username\": \"$USERNAME\",
      \"password\": \"$PASSWORD\",
      \"bucket\": \"$BUCKET\",
      \"users\": {
        \"GUEST\": {
          \"disabled\": false,
          \"admin_channels\": [\"*\"]
        }
      },
      \"allow_conflicts\": false,
      \"revs_limit\": 20,
      \"import_docs\": true,
      \"enable_shared_bucket_access\":true,
      \"num_index_replicas\":0
    }
  }
}      
      " > /opt/sync_gateway/etc/sync_gateway.json
   fi
else
   # Remove existing
   rpm -e "$(rpm -qa | grep couchbase)"
   rm -rf /opt/couchbase-sync-gateway/
   # Update /etc/profile.d/couchbaseserver.sh
    echo "#!/usr/bin/env sh
export COUCHBASE_GATEWAY_VERSION=$VERSION" > /etc/profile.d/couchbaseserver.sh
   bash /setup/couchbase_installer.sh -ch "http://localhost:8091" -u "$USERNAME" -p "$PASSWORD" -v "$VERSION" -os AMAZON -e AWS -c -d -g
   SUCCESS=$?
   echo "
{
  \"interface\":\":4984\",
  \"adminInterface\":\"127.0.0.1:4985\",
  \"metricsInterface\":\":4986\",
  \"logging\": {
    \"console\": {
      \"log_keys\": [\"*\"]
    }
  },
  \"databases\": {
    \"$DATABASE\": {
      \"server\": \"$CLUSTER_HOST\",
      \"username\": \"$USERNAME\",
      \"password\": \"$PASSWORD\",
      \"bucket\": \"$BUCKET\",
      \"users\": {
        \"GUEST\": {
          \"disabled\": false,
          \"admin_channels\": [\"*\"]
        }
      },
      \"allow_conflicts\": false,
      \"revs_limit\": 20,
      \"import_docs\": true,
      \"enable_shared_bucket_access\":true,
      \"num_index_replicas\":0
    }
  }
}      
   " > /opt/sync_gateway/etc/sync_gateway.json
   
fi

if [[ "$SUCCESS" == "0" ]]; then
   # Calls back to AWS to signify that installation is complete
   /opt/aws/bin/cfn-signal -e 0 --stack "$stackName" --resource "$resource" --region "$region"
else
   /opt/aws/bin/cfn-signal -e 1 --stack "$stackName" --resource "$resource" --region "$region"
   exit 1
fi