#! /bin/bash

set -x

REGION=europe-west1
ZONE=$REGION-b
gcloud config set compute/zone $ZONE

NAME=app
GROUP=$NAME-group
TEMPLATE=$NAME-tmpl

gcloud compute instance-groups managed stop-autoscaling $GROUP --zone $ZONE

gcloud compute forwarding-rules delete $NAME-https-rule --region $REGION --quiet
gcloud compute forwarding-rules delete $NAME-http-rule --region $REGION --quiet

gcloud compute target-pools delete $NAME-lb --region $REGION --quiet

gcloud compute http-health-checks delete ah-health-check --quiet

gcloud compute addresses delete $NAME-lb-ip --region $REGION --quiet

gcloud compute instance-groups managed delete $GROUP --quiet  

gcloud compute instance-templates delete $TEMPLATE --quiet 

