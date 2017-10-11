#! /bin/bash

## Checking for local dependencies
# curl
if ! curl -V > /dev/null; then
	echo "Curl, Python and JQ are required."
	exit 1
fi

# python
if ! python -V > /dev/null; then
	echo "Curl, Python and JQ are required."
	exit 1
fi

# jq
if ! jq -V > /dev/null; then
	echo "Curl, Python and JQ are required."
	exit 1
fi

# copied version of config.default.json to config.json
if [ ! -e config.json ]; then
    echo -e "Remember to copy and configure config.default.json to config.json\n\n\tRun:\tmv config.default.json config.json"
    exit 1
fi

## Setting up the Google Cloud SDK
if gcloud --version 2>&1 | grep "Updates are available for some Cloud SDK components." -c; then # Checking for Updates
    gcloud components update --quiet
elif gcloud --version > /dev/null; then # skipping if already installed.
    echo "GCloud SDK already Installing. Skipping init configuration."
else # install gcloud sdk
   curl https://sdk.cloud.google.com > cloudsdk.sh
   chmod +x cloudsdk.sh
   ./cloudsdk.sh --disable-prompts
   rm ./cloudsdk.sh

   echo -e "export PATH=\$PATH:~/google-cloud-sdk/bin" >> ~/.bashrc
   export PATH=$PATH:~/google-cloud-sdk/bin

   gcloud init
fi

## Authenticate if required
if gcloud auth list 2>&1 | grep "No credentialed accounts." -c; then
   gcloud auth login
fi

## Grab project Id from the config file
PROJECTID=$(jq -rc '[ .gcs_project_id ] | .[]' config.json)
gcloud config set project $PROJECTID
gcloud projects list | grep $PROJECTID -c > /dev/null
if [[ $? -eq 0 ]]; then
   gcloud projects create $PROJECTID 2>&1 | grep ERROR -c > /dev/null # Check for errors
   if [[ $? -ne 0 ]]; then
      echo "\"gcs_project_id\":\"$PROJECTID\" in config.json  must be globally unique"
      exit 1
   fi
fi

## Create a random ID for this project
RANDOMVALUE=$RANDOM

## Define the GCS Bucket Name
VMBUCKETVALUE=cf-els-vm-setupfiles-$RANDOMVALUE
VMBUCKET="gs://$VMBUCKETVALUE"

## Make bucket for the VM setup files
gsutil mb -c regional -l us-central1 -p $PROJECTID $VMBUCKET

## Copy config.json and gcs-initialize.sh to Google Cloud Storage
gsutil cp config.json gcs-initialize.sh $VMBUCKET 

## Output newline
echo -e "Creating VM...\n"

## Create the VM
gcloud compute instances create "logshare-cli-cron-$RANDOMVALUE" --zone "us-central1-a" --machine-type "f1-micro" --image "ubuntu-1604-xenial-v20170919" --subnet "default" --metadata "startup-script-url=$VMBUCKET/gcs-initialize.sh,CONFIGBUCKET=$VMBUCKETVALUE,RANDOMVALUE=$RANDOMVALUE" --image-project "ubuntu-os-cloud" --boot-disk-size "10" --boot-disk-type "pd-standard" --scopes "https://www.googleapis.com/auth/cloud-platform" --project $PROJECTID --verbosity="error"

## Output instructions
echo -e "\nSuccessfully kicked off the VM provisioning steps. The VM takes between 4-6 minutes to fully provision.\n\nIf you are seeing any issues, please share them by submitting an issue to the repository. You can view the VM's startup script progress by tailing the syslog file:\n\ttail -f /var/log/syslog\n\nEnjoy!"

