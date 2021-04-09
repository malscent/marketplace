# create instance

```
gcloud compute instances create test-instance-name \
                                    --zone=us-east1-b \
                                    --image-family=ubuntu-1804-lts \
                                    --image-project=ubuntu-os-cloud \
                                    --scopes https://www.googleapis.com/auth/cloud-platform
```

# delete instance

```
gcloud compute instances delete test-instance-name --zone=us-east1-b --keep-disks=boot
```

# Create check instance

```
gcloud compute instances create test-instance-name-check \
                                        --zone=us-east1-b \
                                        --image-family=ubuntu-1804-lts \
                                        --image-project=ubuntu-os-cloud \
                                        --scopes https://www.googleapis.com/auth/cloud-platform

gcloud compute instances attach-disk test-instance-name-check --disk projects/couchbase-dev/zones/us-east1-b/disks/test-instance-name --zone=us-east1-b                    


gcloud compute ssh --project=couchbase-dev --zone=us-east1-b test-instance-name-check
sudo mkdir -p /mnt/disks/disk0
sudo mount /dev/sdb1 /mnt/disks/disk0

```



# create instance with license

```
gcloud compute images create test-image-name \
                        --project couchbase-dev \
                        --source-disk projects/couchbase-dev/zones/us-east1-b/disks/test-instance-name \
                        --licenses projects/couchbase-public/global/licenses/couchbase-sync-gateway-byol \
                        --description "This is a test image with a test license name"
```


