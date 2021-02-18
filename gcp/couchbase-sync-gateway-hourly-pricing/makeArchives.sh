#!/bin/bash

SCRIPT_SOURCE=${BASH_SOURCE[0]/%makeArchives.sh/}

function makeArchive()
{
  license=$1
  dir=$2
  mkdir -p "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package/"
  rm "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/archive-${license}.zip"


  cp "${dir}couchbase.py" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package/couchbase.py"
  cp "${dir}couchbase.py.display" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "${dir}couchbase.py.schema" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "${dir}c2d_deployment_configuration.json" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "${dir}test_config.yaml" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"

  cp "$dir../shared/deployment.py" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/cluster.py" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/group.py" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/naming.py" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/startupCommon.sh" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/server.sh" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/syncGateway.sh" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  cp "$dir../shared/successNotification.sh" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"

  cp -r resources "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"

  zip -r -X "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/gcp-sg-archive-${license}.zip" "$dir../../build/gcp/couchbase-sync-gateway-hourly-pricing/package"
  #rm -rf "$dir../../build/tmp"
}

makeArchive hourly-pricing "$SCRIPT_SOURCE"
