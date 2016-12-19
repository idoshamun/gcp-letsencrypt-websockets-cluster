#!/bin/bash

set -ex

BUCKET=gs://your_certificates_bucket
BUCKET_LOCATION=eu

# Create GCS bucket for the certificates
gsutil mb -c nearline -l $BUCKET_LOCATION $BUCKET/

# Set project wide metadata
gcloud compute project-info add-metadata --metadata certificates-bucket=$BUCKET

# Generate and copy dhparam to GCS
openssl dhparam -out dhparam.pem 2048
gsutil cp dhparam.pem $BUCKET/dhparam.pem
rm dhparam.pem