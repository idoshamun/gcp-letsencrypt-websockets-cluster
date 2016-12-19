#!/bin/bash

set -ex

REGION=europe-west1
ZONE=$REGION-b

NAME=app
GROUP=$NAME-group
TEMPLATE=$NAME-tmpl
MACHINE_TYPE=f1-micro
IMAGE=debian-8
IMAGE_PROJECT=debian-cloud
STARTUP_SCRIPT=startup.sh
SCOPES="userinfo-email,compute-rw,cloud-platform"
TAGS="http-server,https-server"

MIN_INSTANCES=2
MAX_INSTANCES=3
TARGET_UTILIZATION=0.7
COOLDOWN_PERIOD=180

#
# Instance group setup
#

# First we have to create an instance template.
# This template will be used by the instance group
# to create new instances.

# [START create_template]
gcloud compute instance-templates create $TEMPLATE \
  --image-family $IMAGE \
  --image-project $IMAGE_PROJECT \
  --machine-type $MACHINE_TYPE \
  --scopes $SCOPES \
  --metadata-from-file startup-script=$STARTUP_SCRIPT \
  --tags $TAGS
# [END create_template]

# Create the managed instance group.

# [START create_group]
gcloud compute instance-groups managed \
  create $GROUP \
  --base-instance-name $NAME \
  --size $MIN_INSTANCES \
  --template $TEMPLATE \
  --zone $ZONE
# [END create_group]

# [START create_named_port]
gcloud compute instance-groups managed set-named-ports \
    $GROUP \
    --named-ports http:80,https:443 \
    --zone $ZONE
# [END create_named_port]

#
# TCP Load Balancer Setup
#

# [START create_static_address]
gcloud compute addresses create $NAME-lb-ip \
	--region $REGION
# [END create_static_address]

# [START create_health_check]
gcloud compute http-health-checks create ah-health-check \
  --request-path /_ah/health \
  --port 80
# [END create_health_check]

# [START create_target_pool]
gcloud compute target-pools create $NAME-lb \
    --region $REGION \
	--http-health-check ah-health-check \
	--session-affinity CLIENT_IP
# [END create_target_pool]

# [START set_target_pools]
gcloud compute instance-groups managed set-target-pools \
	$GROUP \
	--target-pools $NAME-lb \
	--zone $ZONE
# [END set_target_pools]

STATIC_EXTERNAL_IP=$(gcloud compute addresses describe \
	$NAME-lb-ip --region $REGION | \
	grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)')

# [START create_forwarding_fule]
gcloud compute forwarding-rules create $NAME-http-rule \
    --region $REGION --ports 80 \
    --address $STATIC_EXTERNAL_IP --target-pool $NAME-lb

gcloud compute forwarding-rules create $NAME-https-rule \
    --region $REGION --ports 443 \
    --address $STATIC_EXTERNAL_IP --target-pool $NAME-lb
# [END create_forwarding_fule]

#
# Autoscaler configuration
#
# [START set_autoscaling]
gcloud compute instance-groups managed set-autoscaling \
  $GROUP \
  --max-num-replicas $MAX_INSTANCES \
  --scale-based-on-cpu \
  --target-cpu-utilization $TARGET_UTILIZATION \
  --cool-down-period $COOLDOWN_PERIOD \
  --zone $ZONE
# [END set_autoscaling]
