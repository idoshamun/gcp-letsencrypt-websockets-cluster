# Application Server

To deploy simply run the `deploy.sh` script.

The server is responsible for handling all the domain requests and use Nginx as the web server.

Nginx is used for the following purposes:
- route ACME challenge requests to the Let's Encrypt renewal load balancer
- redirect all other `http` requests to `https`
- handle SSL termination
- redirect traffic to a docker based application server (with WebSockets support)


The docker image is configured as a `systemd` service and should start even on restart.


### Deploy script

- Create an instance template based on debian-8 image and the startup script
- Create a managed instance group based on the template with named port 80 & 443
- Create a static external ip address
- Create a health check with default parameters for the `/_ah/health` endpoint
- Create a TCP load balancer to this instance group for ports 80 & 443 with client ip session affinity
- Set auto-scaler to this instance group


### Startup script

- Install `google-fluentd` agent
- Install `nginx` from apt
- Install `docker` from apt using the official repository
- Download `dhparam` from GCS
- Create bash script for syncing the domain certs from GCS and run it
- Set this script as a daily cron job
- Register the application server as a `systemd` server and enable it
- Generate Nginx configuration

### Teardown script

Destroy everything that was created in the deploy script without
prompting or asking for confirmation, so pay attention!