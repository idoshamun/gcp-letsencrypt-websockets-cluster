# Secured WebSockets cluster on GCP with Let's Encrypt

This project contains bash scripts for deploying a websockets cluster to Google Cloud Platform secured with 
Let's Encrypt SSL certificates.

There is a [medium post](https://blog.elegantmonkeys.com/deploying-websockets-cluster-to-gcp-with-lets-encrypt-certificates-5ebb7fc1e245#.9bi4qp3b5)
which explains the solution architecture and how to run the code, if you want to get more details.

Please make sure [Google Cloud SDK](https://cloud.google.com/sdk/) is installed before using these scripts.

These scripts are developed and tested on Ubuntu 14.04 and haven't been tried on any other OS or version.
___

### Overview

The project is divided to three components:
- [Let's Encrypt renewal server](letsencrypt) - responsible for renewing the Let's Encrypt certificates and handling the
ACME challenge
- [Application server](server) - contains Nginx server to route the traffic to the local app server (docker based) or to
the renewal server
- [WebSockets demo](websockets-demo) - simple echo websockets server written in NodeJS

The [pre-deploy.sh](pre-deploy.sh) script creates a new bucket to store all the SSL certificates. In addition, it stores
the path to the bucket as a project metadata and generates a `dhparam` that will later be used by Nginx.

All the scripts are fully parameterized and the parameters can be found at the beginning of the scripts.

##### Please notice

You can't deploy the application server before you already have the certificates stored in GCS.
So when first issuing the certificates, point your DNS to the external ip of the Let's Encrypt instance.
After issuing, you can continue with the deployment and point the DNS to the static ip of the `app-lb`.

___

### Credits

- [Nginx configuration](https://gist.github.com/plentz/6737338)
- [Let's Encrypt integration with GCP](http://blog.vuksan.com/2016/04/18/google-compute-load-balancer-lets-encrypt-integration)
- [Google Compute Engine automation scripts](https://github.com/GoogleCloudPlatform/nodejs-getting-started/tree/master/7-gce)