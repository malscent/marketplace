#!/bin/bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%deploy.sh/}

"${SCRIPT_SOURCE}/makeArchives.sh"

cd "${SCRIPT_SOURCE}../../build/gcp/couchbase-enterprise-edition-hourly-pricing/package/" || exit 1

gcloud deployment-manager deployments create cbs-ee-cicd-testing-hourly \
    --config=test_config.yaml \
    --description="Couchbase Enterprise Edition Marketplace Offering Hourly Pricing Testing"