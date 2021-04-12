#!/bin/bash

set -eu 

###############################################################################
# Dependencies:                                                               #
# gcloud                                                                      #
# tr                                                                          #
###############################################################################

###############################################################################
#  Parameters                                                                 #
#  -l :  license                                                              #
#     usage: -l couchbase-server-ee-hourly-pricing                            #
#     purpose: license to be added to the image                               #     
#  -n : name                                                                  #
#     usage:  -n couchbase-server-ee-byol                                     #
#     purpose:  The name of the image (post-fixed with vYYYYMMDD)             #
#  -z : zone                                                                  #
#     usage: -z us-east1-b                                                    #
#     purpose: specifies the zone in which to create the image                #
#  -p : GCP Project                                                           #
#     usage: -p couchbase-public                                              #
#     purposes: The project to create the images in                           #
#  -f : Image Family                                                          #
#     usage: -v ubuntu-1804-lts                                               #
#     purposes: this is the family name to use to create the base instance    #
#  -i : Image Project                                                         #
#     usage: -i ubuntu-os-cloud                                               #
#     purposes: The project name in which the base OS resides                 #
###############################################################################

function __generate_random_string() {
    NEW_UUID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 10 ; echo '')
    echo "${NEW_UUID}"
}

while getopts l:n:z:p:f:i: flag
do
    case "${flag}" in
        l) license=${OPTARG};;
        n) name=${OPTARG};;
        z) zone=${OPTARG};;
        p) project=${OPTARG};;
        f) family=${OPTARG};;
        i) image_project=${OPTARG};;
        *) exit 1;;
    esac
done

date=$(date '+%Y%m%d')
image_name="$name-v$date"
random_string=$(__generate_random_string)
instance_name="$name-$random_string"
echo "Creating instance: $instance_name"
createInstanceResponse=$(gcloud compute instances create "$instance_name" \
                                                 --zone="$zone" \
                                                 --image-family="$family" \
                                                 --image-project="$image_project" \
                                                 --project="$project" \
                                                 --scopes "https://www.googleapis.com/auth/cloud-platform")

echo "Create Instance Response: $createInstanceResponse"
echo "Deleting Instance but preserving boot disk"
gcloud compute instances delete "$instance_name" --zone="$zone" --project="$project" --keep-disks=boot -q
echo "Creating Image from boot disk"
createImageResponse=$(gcloud compute images create "$image_name" \
                        --project "$project" \
                        --source-disk "projects/$project/zones/$zone/disks/$instance_name" \
                        --licenses "projects/$project/global/licenses/$license" \
                        --family="$name")
echo "Create Image Response: $createImageResponse"                        