#!/bin/bash

set -ex

ZONE=europe-west1-b

NAME=letsencrypt
GROUP=$NAME-group
TEMPLATE=$NAME-tmpl
MACHINE_TYPE=f1-micro
IMAGE=debian-8
IMAGE_PROJECT=debian-cloud
STARTUP_SCRIPT=startup.sh
SCOPES="userinfo-email,compute-rw,cloud-platform"
TAGS="lets-encrypt,http-server"

MIN_INSTANCES=1
MAX_INSTANCES=1
TARGET_UTILIZATION=0.5
COOLDOWN_PERIOD=270

SERVICE=$NAME-service


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
  --tags $TAGS \
  --description "Instance template for Lets Encrypt SSL renewal machine"
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
    --named-ports http:80 \
    --zone $ZONE
# [END create_named_port]

#
# Load Balancer Setup
#

# A complete HTTP load balancer is structured as follows:
#
# 1) A global forwarding rule directs incoming requests to a target HTTP proxy.
# 2) The target HTTP proxy checks each request against a URL map to determine the
#    appropriate backend service for the request.
# 3) The backend service directs each request to an appropriate backend based on
#    serving capacity, zone, and instance health of its attached backends. The
#    health of each backend instance is verified using either a health check.
#
# We'll create these resources in reverse order:
# service, health check, backend service, url map, proxy.

# Create a health check
# The load balancer will use this check to keep track of which instances to send traffic to.
# Note that health checks will not cause the load balancer to shutdown any instances.

# [START create_health_check]
gcloud compute http-health-checks create root-health-check \
  --request-path / \
  --port 80
# [END create_health_check]

# Create a backend service, associate it with the health check and instance group.
# The backend service serves as a target for load balancing.

# [START create_backend_service]
gcloud compute backend-services create $SERVICE \
  --http-health-checks root-health-check \
  --port 80 \
  --global
# [END create_backend_service]

# [START add_backend_service]
gcloud compute backend-services add-backend $SERVICE \
  --instance-group $GROUP \
  --instance-group-zone $ZONE \
  --global
# [END add_backend_service]

# Create a URL map and web Proxy. The URL map will send all requests to the
# backend service defined above.

# [START create_url_map]
gcloud compute url-maps create $NAME-lb \
  --default-service $SERVICE
# [END create_url_map]

# [START create_http_proxy]
gcloud compute target-http-proxies create $NAME-proxy \
  --url-map $NAME-lb
# [END create_http_proxy]

# Create a global forwarding rule to send all traffic to our proxy

# [START create_forwarding_rule]
gcloud compute forwarding-rules create $NAME-http-rule \
  --global \
  --target-http-proxy $NAME-proxy \
  --ports 80
# [END create_forwarding_rule]

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

# [START update_project_metadata]
STATIC_EXTERNAL_IP=$(gcloud compute forwarding-rules describe \
	$NAME-http-rule --global | \
	grep -E -o '(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)')

gcloud compute project-info add-metadata --metadata letsencrypt-lb=$STATIC_EXTERNAL_IP
# [END update_project_metadata]
