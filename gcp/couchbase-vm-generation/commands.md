# create instance

```gcloud compute instances create test-instance-name --zone=us-east1-b --image-family=ubuntu-1804-lts --image-project=ubuntu-os-cloud --scopes https://www.googleapis.com/auth/cloud-platform```

# delete instance

```gcloud compute instances delete test-instance-name --zone=us-east1-b --keep-disks=boot```\

# create instance with license

```
gcloud compute images create test-image-name \
                        --project couchbase-dev \
                        --source-disk projects/couchbase-dev/zones/us-east1-b/disks/test-instance-name \
                        --licenses projects/couchbase-public/global/licenses/couchbase-sync-gateway-byol \
                        --description "This is a test image with a test license name"
```


