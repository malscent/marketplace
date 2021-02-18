#!/bin/bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%deploy.sh/}

"${SCRIPT_SOURCE}/makeArchives.sh"

cd "${SCRIPT_SOURCE}../../build/gcp/couchbase-sync-gateway-hourly-pricing/package/" || exit 1

gcloud deployment-manager deployments create cb-sg-cicd-testing-hourly \
    --config=test_config.yaml \
    --description="Couchbase Sync Gateway Marketplace Offering Hourly Pricing Testing"