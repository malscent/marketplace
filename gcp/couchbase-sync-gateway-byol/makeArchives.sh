#!/bin/bash

function makeArchive()
{
  license=$1
  mkdir -p ../../build/gcp/couchbase-sync-gateway-byol/
  rm ../../build/gcp/couchbase-sync-gateway-byol/archive-${license}.zip
  mkdir -p ../../build/tmp


  cp couchbase-${license}.py ../../build/tmp/couchbase.py
  cp couchbase.py.display ../../build/tmp
  cp couchbase.py.schema ../../build/tmp
  cp c2d_deployment_configuration.json ../../build/tmp
  cp test_config.yaml ../../build/tmp

  cp ../shared/deployment.py ../../build/tmp
  cp ../shared/cluster.py ../../build/tmp
  cp ../shared/group.py ../../build/tmp
  cp ../shared/naming.py ../../build/tmp
  cp ../shared/startupCommon.sh ../../build/tmp
  cp ../shared/server.sh ../../build/tmp
  cp ../shared/syncGateway.sh ../../build/tmp
  cp ../shared/successNotification.sh ../../build/tmp

  cp -r resources ../../build/tmp

  zip -r -X ../../build/gcp/couchbase-sync-gateway-byol/archive-${license}.zip ../../build/tmp
  rm -rf ../../build/tmp
}

makeArchive byol
