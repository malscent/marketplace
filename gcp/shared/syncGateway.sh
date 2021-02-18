echo "Running syncGateway.sh"

FILE="/var/lib/dpkg/lock-frontend"
DB="/var/lib/dpkg/lock"
if [[ -f "$FILE" ]]; then
  PID=$(lsof -t $FILE)
  echo "lock-frontend locked by $PID"
  echo "Killing $PID"
  kill -9 "${PID##p}"
  echo "$PID Killed"
  rm $FILE
  PID=$(lsof -t $DB)
  echo "DB locked by $PID"
  kill -9 "${PID##p}"
  if ps -p "${PID##p}" > /dev/null
  then
    __log_error "${PID} was not successfully killed, Installation cannot continue"
    exit 1
  fi
  rm $DB
  dpkg --configure -a
fi

echo "Installing Couchbase Sync Gateway..."
wget https://packages.couchbase.com/releases/couchbase-sync-gateway/${syncGatewayVersion}/couchbase-sync-gateway-enterprise_${syncGatewayVersion}_x86_64.deb
dpkg -i couchbase-sync-gateway-enterprise_${syncGatewayVersion}_x86_64.deb

echo "Configuring Couchbase Sync Gateway..."
file="/home/sync_gateway/sync_gateway.json"
echo '
{
  "interface": "0.0.0.0:4984",
  "adminInterface": "0.0.0.0:4985",
  "log": ["*"]
}
' > ${file}
chmod 755 ${file}
chown sync_gateway ${file}
chgrp sync_gateway ${file}

# Need to restart to load the changes
service sync_gateway stop
service sync_gateway start

#######################################################
####### Wait until web interface is available #########
#######################################################

checksCount=0

printf "Waiting for server startup..."
until curl -o /dev/null -s -f http://localhost:4985/_admin || [[ $checksCount -ge 50 ]]; do
   (( checksCount += 1 ))
   printf "." && sleep 3
done
echo "server is up."