#! /bin/bash

set -x

ZONE=europe-west1-b
gcloud config set compute/zone $ZONE

NAME=letsencrypt
GROUP=$NAME-group
TEMPLATE=$NAME-tmpl
SERVICE=$NAME-service

gcloud compute instance-groups managed stop-autoscaling $GROUP --zone $ZONE

gcloud compute forwarding-rules delete $NAME-http-rule --global --quiet

gcloud compute target-http-proxies delete $NAME-proxy --quiet 

gcloud compute url-maps delete $NAME-lb --quiet 

gcloud compute backend-services delete $SERVICE --global --quiet

gcloud compute http-health-checks delete root-health-check --quiet

gcloud compute instance-groups managed delete $GROUP --quiet  

gcloud compute instance-templates delete $TEMPLATE --quiet 

