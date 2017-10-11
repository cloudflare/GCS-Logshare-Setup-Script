#! /bin/bash

if [ ! -e /root/.secondboot ]; then
    logger "Creating dot file to prevent multiple executions"
    touch /root/.secondboot

    # Run Dependencies
    logger "Installing dependencies: jq git zip golang1.8"
    add-apt-repository ppa:gophers/archive -y
    apt-get update
    apt-get install -y jq git zip golang-1.8

    mkdir /root/go
    export GOPATH=/root/go
    export PATH=$PATH:/usr/lib/go-1.8/bin
    export RANDOMVALUE=`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/RANDOMVALUE -H "Metadata-Flavor: Google"`

    # Export Go Environment Variables
    echo -e "export GOPATH=/root/go\nexport PATH="$PATH:/usr/lib/go-1.8/bin"" >> /root/.bashrc

    # Get logshare-cli
    logger "Cloning Cloudflare Logshare" 
    /usr/lib/go-1.8/bin/go get github.com/cloudflare/logshare/...
    go get github.com/cloudflare/logshare/...

    # Copy GCS config files
    logger "Copying Config files from bucket"
    gsutil cp gs://`curl http://metadata.google.internal/computeMetadata/v1/instance/attributes/CONFIGBUCKET -H "Metadata-Flavor: Google"`/config.json /root/

    # Export config.json into environment variables
    logger "Exporting environment variables from config file"
    echo "export APIKEY=`jq -r .cloudflare_api_key /root/config.json`" >> /root/.bashrc
    export APIKEY=`jq -r .cloudflare_api_key /root/config.json`

    echo "export APIEMAIL=`jq -r .cloudflare_api_email /root/config.json`" >> /root/.bashrc
    export APIEMAIL=`jq -r .cloudflare_api_email /root/config.json`

    echo "export ZONENAME=`jq -r .zone_name /root/config.json`" >> /root/.bashrc
    export ZONENAME=`jq -r .zone_name /root/config.json`

    # Source bashrc
    source /root/.bashrc


    # Create one-time fields.txt - outputs all available fields as of creation - may need to be updated in future
    logger "Caching most recent fields from ELS /received endpoint"
    /root/go/bin/logshare-cli --api-key=$APIKEY --api-email=$APIEMAIL --zone-name $ZONENAME --list-fields 2> /dev/null | jq -r '. | keys_unsorted | @csv' | tr -d '"' > /root/fields.txt

    # Create cron-script.sh
    logger "Creating local cron script file"
    touch /root/cron-script.sh

    # GCloud Init
    logger "setting default project id for gcloud config"
    gcloud config set project `jq -r .gcs_project_id /root/config.json`

    # Create Bucket Name
    logger "creating log bucket in GCS"
    export GSB=`jq -r .gcs_project_id /root/config.json`-logs-$RANDOMVALUE
    
    # Create Staging Bucket Name
    logger "creating staging bucket for setup files"
    export GSBSTAGING=`jq -r .gcs_project_id /root/config.json`-staging-$RANDOMVALUE


    logger "provisioning logshare-cli command with cloudflare credentials"
    echo -e "START=\`date +%s --date '-11 minutes'\`\nEND=\`date +%s --date '-10 minutes'\`\n\n/root/go/bin/logshare-cli --api-key=$APIKEY --api-email=$APIEMAIL --zone-name=$ZONENAME --count=-1 --by-received --google-storage-bucket=$GSB --google-project-id=`jq -r .gcs_project_id /root/config.json` --start-time=\$START --end-time=\$END --fields `cat /root/fields.txt` >> /root/logshare-cli.log 2>&1" > /root/cron-script.sh

    # Create two Buckets - One for the Logs and one for the Staging Files
    logger "provisioning both gcs buckets"
    gsutil mb -c regional -l us-central1 "gs://$GSB"
    gsutil mb -c regional -l us-central1 "gs://$GSBSTAGING"

    # Configure the Cloud Function
    logger "cloning the cloud function repo"
    git clone https://github.com/cloudflare/GCS-To-Big-Query.git /root/GCS-To-Big-Query

    # Update the GCS config file with the project identifier
    echo '{"DATASET": "cloudflare_logs_'$RANDOMVALUE'","TABLE": "cloudflare_els_'$RANDOMVALUE'"}' > /root/GCS-To-Big-Query/config.json

    logger "zipping up files for cloud function"
    zip -j /root/archive.zip /root/GCS-To-Big-Query/*

    logger "copying setup files to staging bucket"
    gsutil cp /root/archive.zip gs://$GSBSTAGING

    logger "deploying cloud function"
    gcloud beta functions deploy cflogs_upload_bucket_$RANDOMVALUE --trigger-bucket=gs://$GSB --source=gs://$GSBSTAGING/archive.zip --stage-bucket=gs://$GSBSTAGING --entry-point=jsonLoad

    chmod +x /root/cron-script.sh

    logger "provisioning cronjob"
    crontab -l > file; echo '* * * * * /root/cron-script.sh' >> file; crontab file

else
    logger "Second boot"
fi
