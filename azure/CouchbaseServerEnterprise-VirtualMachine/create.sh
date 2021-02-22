#!/bin/bash

###############################################################################
# Dependencies:                                                               #
# azure cli                                                                   #
# JQ                                                                          #
# sshpass                                                                     #
###############################################################################

###############################################################################
#  Parameters                                                                 #
#  -l :  Location                                                             #
#     usage: -l eastus                                                        #
#     purpose: Location based on az account list-locations                    #     
#  -g : Resource Group                                                        #
#     usage: -g ja-test-1                                                     #
#     purpose: Specifies the name of the resource group to use. Will create   #
#              if not exists                                                  #
#  -s : Storage Account Name                                                  #
#     usage: -s cb-see-mkt-offer-sa                                           #
#     purposes: names storage account to use                                  #
#  -v : Version of the VM                                                     #
#     usage: -v 2.0.0                                                         #
#     purposes: specify the version of the os disk for the marketplace        # 
###############################################################################

#  Generates a 13 character random string
function __generate_random_string() {
    LENGTH=$1
    NEW_UUID=$(LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c $LENGTH ; echo '')
    echo "${NEW_UUID}"
}

RANDOM_STRING=$(__generate_random_string 8)
VM_NAME="cb_template_${RANDOM_STRING}"
SCRIPT_SOURCE=${BASH_SOURCE[0]/%create.sh/}
mkdir -p "$SCRIPT_SOURCE../../build/azure/CouchbaseServerEnterprise-VirtualMachine/"
SKU="18.04-LTS"
while getopts l:g:s:k:v: flag
do
    case "${flag}" in
        l) LOCATION=${OPTARG};;
        g) RESOURCE_GROUP=${OPTARG};;
        s) NAME=${OPTARG};;
        k) SKU=${OPTARG:="18.04-LTS"};;
        v) VERSION=${OPTARG:="2.0.0"};;
        *) exit 1;;
    esac
done

if [[ -z "${SKU// }" ]]; then
    echo "SKU not selected, please select a SKU from 'az vm image list -f UbuntuServer --all'"
    exit 1
fi

echo "Location: ${LOCATION}"
echo "Resource Group: ${RESOURCE_GROUP}"
echo "Storage Account Name: ${NAME}"
echo "SKU: ${SKU}"

location_exists=$(az account list-locations -o json | jq ".[] | .name" | grep "${LOCATION}" -c)

if [ "$location_exists" = 0 ]; then
    echo "Invalid location."
    exit 1
fi


group_exists=$(az group exists --name "${RESOURCE_GROUP}")
if [ "$group_exists" = "true" ]; then
    echo "Group Exists, skipping creation"
else
    az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output table
fi

VM_IMAGE=$(az vm image list -f UbuntuServer --all | jq '[.[] | select(.sku=='\""$SKU"\"')] | .[-1]')
IMAGE_URN=$(echo $VM_IMAGE | jq -r '.urn')
echo "Creating image on $IMAGE_URN"

storage_exists=$(az storage account check-name --name "$NAME" | jq -r '.reason')

if [[ "$storage_exists" == "AccountNameInvalid" ]]; then
    echo "Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only."
    exit 1
fi

if [[ "$storage_exists" != "AlreadyExists" ]]; then
    echo "Storage account does not exist.  Creating..."
    az storage account create --sku Premium_LRS --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --name "$NAME" -o json &> /dev/null
else
    echo "Storage account exists.  Skipping creation."
fi

BLOB_ENDPOINT=$(az storage account show --name "$NAME" -o json | jq -r '.primaryEndpoints | .blob')

echo "Primary Blob Endpoint: $BLOB_ENDPOINT"

echo "Creating Base VM"
RANDOM_PASSWORD=$(__generate_random_string 16)
VM_RESPONSE=$(az vm create \
                --name "$VM_NAME" \
                --resource-group "$RESOURCE_GROUP" \
                --image "$IMAGE_URN" \
                --admin-username couchbase \
                --admin-password "$RANDOM_PASSWORD" \
                --use-unmanaged-disk \
                --storage-account "$NAME" \
                )
VM_IP=$(echo "$VM_RESPONSE" | jq -r '.publicIpAddress' )
VM_ID=$(echo "$VM_RESPONSE" | jq -r '.id')
echo "VM Created and listening at: $VM_IP"
echo "VM Name: $VM_NAME"
echo "VM ID: $VM_ID"
echo "If I crash, please run 'az vm delete --ids $VM_ID --yes'"

# If we decide to do more than just an empty OS. .we need to do it before we run this command, as you won't be able to log into the VM once we're done
sshpass -p "$RANDOM_PASSWORD" ssh -o StrictHostKeyChecking=no "couchbase@$VM_IP" "sudo waagent -deprovision+user -force && exit"

az vm deallocate --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"
az vm generalize --resource-group "$RESOURCE_GROUP" --name "$VM_NAME"

CONNECTION_STRING=$(az storage account show-connection-string --resource-group "$RESOURCE_GROUP" --name "$NAME")

STORAGE_BLOB=$(az vm show --name "$VM_NAME" --resource-group "$RESOURCE_GROUP" | jq '.storageProfile.osDisk')
BLOB_NAME=$(echo "$STORAGE_BLOB" | jq -r '.name')
YEAR=$(date +%Y)
MONTH=$(date +%m)
DAY=$(date +%d)
EXPIRY_YEAR=$((YEAR + 5))
START="${YEAR}-${MONTH}-${DAY}"
EXPIRY="${EXPIRY_YEAR}-${MONTH}-${DAY}"
SAS_SUFFIX=$(az storage container generate-sas -n vhds --connection-string "$CONNECTION_STRING" --start "$START" --expiry "$EXPIRY" --permissions rl | jq -r)


echo "URL IS: ${BLOB_ENDPOINT}vhds/${BLOB_NAME}?${SAS_SUFFIX}"

# output to build in "TechincalConfiguration.json"

echo "{
    \"osFamily\": \"linux\",
    \"osFriendlyName\": \"Canonical Ubuntu Server ${SKU}\",
    \"diskVersion\": \"${VERSION}\",
    \"osVHDLink\": \"${BLOB_ENDPOINT}vhds/${BLOB_NAME}?${SAS_SUFFIX}\",
    \"recommendedVMSizes\": [],
    \"openPorts\": [],
    \"generationType\": \"Generation 1\"
}" > "${SCRIPT_SOURCE}../../build/azure/CouchbaseServerEnterprise-VirtualMachine/TechnicalConfiguration.json"

echo "Tearing down Resources"
az vm delete --ids "$VM_ID" --yes
az resource delete --name "${VM_NAME}VMNic" --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Network/networkInterfaces"
az resource delete --name "${VM_NAME}VNET" --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Network/virtualNetworks"
az resource delete --name "${VM_NAME}PublicIP" --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Network/publicIPAddresses"
az resource delete --name "${VM_NAME}NSG" --resource-group "$RESOURCE_GROUP" --resource-type "Microsoft.Network/networkSecurityGroups"
