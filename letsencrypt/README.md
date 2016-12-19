# Let's Encrypt Renewal Server

To deploy simply run the `deploy.sh` script.

The instance use the quay.io/letsencrypt/letsencrypt docker image to trigger renewal of the
certificates and a simple apache2 server to handle the ACME challenge.

The server contains `/root/renew.sh` script to easily renew the certificates.

Usage: `sudo /root/renew.sh yourdomain.com` *(sudo is required)*


### Deploy script

- Create an instance template based on debian-8 image and the startup script
- Create a managed instance group based on the template with named port 80
- Create a health check with default parameters for the root endpoint
- Create a HTTP load balancer to this instance group
- Set auto-scaler to this instance group to one instance only
- Update project metadata with the HTTP load balancer IP


### Startup script

- Install `google-fluentd` agent
- Install `apache2` from apt
- Install `docker` from apt using the official repository
- Change the default `index.html` of apache server
- Initialize `letsencrypt` configuration in `/root/ssl`
- Create the `renew.sh` script

### Teardown script

Destroy everything that was created in the deploy script without
prompting or asking for confirmation, so pay attention!