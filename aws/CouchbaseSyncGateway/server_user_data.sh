#!/usr/bin/env bash

set -ex

USERNAME=__USERNAME__
PASSWORD=__PASSWORD__

yum install jq aws-cfn-bootstrap -y -q

CLUSTER_HOST=$(curl -sf http://169.254.169.254/latest/meta-data/public-hostname) || CLUSTER_HOST=$(hostname)

CLUSTER_MEMBERSHIP=$(curl -q -u "$USERNAME:$PASSWORD" http://127.0.0.1:8091/pools/default | jq -r '') || CLUSTER_MEMBERSHIP="unknown pool"
if [[ "$CLUSTER_MEMBERSHIP" != "unknown pool" ]] && curl -q -u "$USERNAME:$PASSWORD" http://127.0.0.1:8091/pools/default; then
    exit
else
    export CLI_INSTALL_LOCATION="/opt/couchbase/bin/"
    bash /setup/postinstall.sh 0
    bash /setup/posttransaction.sh 
    bash /setup/couchbase_installer.sh -ch "$CLUSTER_HOST" -u "$USERNAME" -p "$PASSWORD" -v "6.6.2" -os AMAZON -e AWS -s -c -d --cluster-only
    /opt/couchbase/bin/couchbase-cli bucket-create --cluster "$CLUSTER_HOST" -u "$USERNAME" -p "$PASSWORD" --bucket "default" --bucket-type "couchbase" --bucket-ramsize 1024
fi 