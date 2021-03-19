#!/usr/bin/env bash
set -eu

SCRIPT_SOURCE=${BASH_SOURCE[0]/%script_url_replacer.sh/}
echo "Source: $SCRIPT_SOURCE"
TARGET_FILE=$1
REPLACEMENT="__SCRIPT_URL__"
SCRIPT_URL=$(cat "${SCRIPT_SOURCE}script_url.txt")
SED_VALUE="s~$REPLACEMENT~$SCRIPT_URL~g"

echo "Target: $TARGET_FILE"
echo "Replacement Const: $REPLACEMENT"
echo "SED Args: ${SED_VALUE}"

echo "Target URI: ${TARGET_FILE}"
sed -i '' "$SED_VALUE" "$TARGET_FILE"
