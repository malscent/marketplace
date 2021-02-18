#!/bin/bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%deploy.sh/}

"${SCRIPT_SOURCE}/makeArchives.sh"

cd "${SCRIPT_SOURCE}../../build/gcp/couchbase-enterprise-edition-byol/package/" || exit 1

gcloud deployment-manager deployments create cbs-ee-cicd-testing-byol \
    --config=test_config.yaml \
    --description="Couchbase Enterprise Edition Marketplace Offering BYOL Testing"