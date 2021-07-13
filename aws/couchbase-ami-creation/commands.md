# Create instance


```
BASE_AMI_ID=$(aws ssm get-parameters --names /aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2 --region $REGION | jq -r '.Parameters[] | .Value')
INSTANCE_TYPE=m4.xlarge
SECURITY_GROUP=default

aws ec2 run-instances \
    --image-id $BASE_AMI_ID \
    --instance-type $INSTANCE_TYPE \
    --security-groups $SECURITY_GROUP \
    --key-name $KEY_NAME \
    --region $REGION
```

`wget -O couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm  "https://packages.couchbase.com/releases/6.6.2/couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm"`

`wget -O couchbase_installer.sh https://github.com/couchbase-partners/marketplace-scripts/releases/download/v1.0.10/couchbase_installer.sh`

`rpm -qp --scripts couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm`  Get scripts

Pre install scripts
```
if test X"$RPM_INSTALL_PREFIX0" = X"" ; then
  RPM_INSTALL_PREFIX0=/opt/couchbase
fi

if test X"$RPM_INSTALL_PREFIX1" = X"" ; then
  RPM_INSTALL_PREFIX1=/usr/lib/systemd/system
fi

getent group couchbase >/dev/null || \
   groupadd -r couchbase || exit 1
getent passwd couchbase >/dev/null || \
   useradd -r -g couchbase -d $RPM_INSTALL_PREFIX0 -s /sbin/nologin \
           -c "Couchbase system user" couchbase || exit 1

# If Couchbase was previously installed here, stop it
if [ -e $RPM_INSTALL_PREFIX1/couchbase-server.service ]
then
  if [ -x /opt/couchbase/bin/install/systemd-ctl ]
  then
    /opt/couchbase/bin/install/systemd-ctl stop
  else
    systemctl stop couchbase-server || true
  fi
fi
# Also check for legacy installs
if [ -x /etc/init.d/couchbase-server ]
then
  /etc/init.d/couchbase-server stop || true
fi

if [ -d /opt/couchbase ]
then
  find /opt/couchbase -maxdepth 1 -type l | xargs rm -f || true
fi

if test -f /sys/kernel/mm/transparent_hugepage/enabled ; then
  if ! grep -q "\[never\]" /sys/kernel/mm/transparent_hugepage/enabled ; then
    cat <<EOF
Warning: Transparent hugepages looks to be active and should not be.
Please look at https://docs.couchbase.com/server/6.6/install/thp-disable.html as for how to PERMANENTLY alter this setting.
EOF
  fi
fi

if test -f /sys/kernel/mm/redhat_transparent_hugepage/enabled ; then
  if ! grep -q "\[never\]" /sys/kernel/mm/redhat_transparent_hugepage/enabled ; then
    cat <<EOF
Warning: Transparent hugepages looks to be active and should not be.
Please look at https://docs.couchbase.com/server/6.6/install/thp-disable.html as for how to PERMANENTLY alter this setting.
EOF
  fi
fi

SWAPPINESS=`cat /proc/sys/vm/swappiness`
if [ "$SWAPPINESS" -ne "0" ]
then
    cat <<EOF
Warning: Swappiness is not set to 0.
Please look at https://docs.couchbase.com/server/6.6/install/install-swap-space.html as for how to PERMANENTLY alter this setting.
EOF
fi

RAM=`grep 'MemTotal' /proc/meminfo | sed 's/MemTotal:\s*//g' | sed 's/\skB//g' | awk '{printf "%.2f", $1/1024/1024}'`
CPU=`grep 'processor' /proc/cpuinfo | sort -u | wc -l`

cat <<EOF
Minimum RAM required  : 4 GB
System RAM configured : $RAM GB

Minimum number of processors required : 4 cores
Number of processors on the system    : $CPU cores

EOF

exit 0
```

Post Install Script
```
if test X"$RPM_INSTALL_PREFIX0" = X"" ; then
  RPM_INSTALL_PREFIX0=/opt/couchbase
fi

`cd $RPM_INSTALL_PREFIX0 && ./bin/install/reloc.sh $RPM_INSTALL_PREFIX0`

if [ "`uname -m`" != "x86_64" ]
then
  cat <<EOF
ERROR: The machine architecture does not match this build
of the software.  For example, installing a 32-bit build
on a 64-bit machine, or vice-versa.  Please uninstall and
install a build with a matching architecture.

EOF
  exit 1
fi

# From https://www.rpm.org/max-rpm-snapshot/s1-rpm-inside-scripts.html
# The argument to the %post script is >1 on an upgrade.

if [ -n "$INSTALL_UPGRADE_CONFIG_DIR" -o $1 -gt 1 ]
then
  if [ -z "$INSTALL_UPGRADE_CONFIG_DIR" ]
  then
    INSTALL_UPGRADE_CONFIG_DIR=$RPM_INSTALL_PREFIX0/var/lib/couchbase/config
  fi
  echo Upgrading couchbase-server ...
  echo "  $RPM_INSTALL_PREFIX0/bin/cbupgrade -c $INSTALL_UPGRADE_CONFIG_DIR -a yes $INSTALL_UPGRADE_EXTRA"
  if [ "$INSTALL_DONT_AUTO_UPGRADE" != "1" ]
  then
    $RPM_INSTALL_PREFIX0/bin/cbupgrade -c $INSTALL_UPGRADE_CONFIG_DIR -a yes $INSTALL_UPGRADE_EXTRA 2>&1 || exit 1
  else
    echo Skipping cbupgrade due to INSTALL_DONT_AUTO_UPGRADE ...
  fi
fi

exit 0
preuninstall scriptlet (using /bin/sh):

if test X"$RPM_INSTALL_PREFIX0" = X"" ; then
  RPM_INSTALL_PREFIX0=/opt/couchbase
fi

# $1 will be 0 only if this is a full uninstall (as opposed to an upgrade)
if [ "$1" = "0" ]
then
  /opt/couchbase/bin/install/systemd-ctl stop
fi

rm -f $RPM_INSTALL_PREFIX0/bin/*.bin

exit 0
postuninstall scriptlet (using /bin/sh):

# $1 will be 0 only if this is a full uninstall (as opposed to an upgrade)
if [ "$1" = "0" ]
then
  # Delete un-owned files like .pyc and __pycache__
  rm -rf $RPM_INSTALL_PREFIX0/lib/python
  # If this resulted in empty lib/ dir, delete that too
  rmdir $RPM_INSTALL_PREFIX0/lib &> /dev/null || true
fi
posttrans scriptlet (using /bin/sh):

if test X"$RPM_INSTALL_PREFIX0" = X"" ; then
  RPM_INSTALL_PREFIX0=/opt/couchbase
fi

/opt/couchbase/bin/install/systemd-ctl daemon-reload
/opt/couchbase/bin/install/systemd-ctl enable
if [ "$INSTALL_DONT_START_SERVER" != "1" ]
then
  /opt/couchbase/bin/install/systemd-ctl start
else
  echo Skipping server start due to INSTALL_DONT_START_SERVER ...
fi

cat <<EOF

You have successfully installed Couchbase Server.
Please browse to http://`hostname`:8091/ to configure your server.
Refer to https://docs.couchbase.com for additional resources.

Please note that you have to update your firewall configuration to
allow external connections to a number of network ports for full
operation. Refer to the documentation for the current list:
https://docs.couchbase.com/server/6.6/install/install-ports.html

By using this software you agree to the End User License Agreement.
See $RPM_INSTALL_PREFIX0/LICENSE.txt.

EOF

exit 0
```

Run from root directory so it installs in correct location

`rpm2cpio couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm  | cpio -idmv`


`START=$(rpm -qp --scripts couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm | grep -n 'preinstall scriptlet (using /bin/sh):' | cut -d ":" -f 1)`

`START=$(($START + 1))`

`STOP=$(rpm -qp --scripts couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm | grep -n 'postinstall scriptlet (using /bin/sh):' | cut -d ":" -f 1)`

`STOP=$(($STOP - 1))`

`SED="${START},${STOP}p"`

`rpm -qp --scripts couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm | sed -n $SED > preinstall.sh`

`yum deplist couchbase-server-enterprise-6.6.2-amzn2.x86_64.rpm | awk '/provider:/ {print $2}' | sort -u | xargs sudo yum -y install`