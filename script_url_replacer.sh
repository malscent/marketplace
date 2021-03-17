#!/usr/bin/env bash
set -eu

SCRIPT_SOURCE=${BASH_SOURCE[0]/%script_url_replacer.sh/}

TARGET_FILE=$1
REPLACEMENT="__SCRIPT_URL__"
SCRIPT_URL=$(cat "${SCRIPT_SOURCE}script_url.txt")
SED_VALUE="s~$REPLACEMENT~$SCRIPT_URL~g"

echo "Target: $TARGET_FILE"
echo "Replacement Const: $REPLACEMENT"
echo "SED Args: ${SED_VALUE}"

if [[ "$TARGET_FILE" == ".*" ]]; then
    sed -i '' "$SED_VALUE" "${SCRIPT_SOURCE}${TARGET_FILE}"
else
    sed -i '' "$SED_VALUE" "$TARGET_FILE"
fi