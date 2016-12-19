#!/bin/bash

DOMAIN=yourdomain.com
DOCKER_IMAGE=elegantmonkeys/websockets-demo
DOCKER_PORT=3000

bucket=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/certificates-bucket" -H "Metadata-Flavor: Google")
letsencrypt=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/letsencrypt-lb" -H "Metadata-Flavor: Google")


# Install logging monitor. The monitor will automatically pick up logs sent to
# syslog.
# [START logging]
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &
# [END logging]

# Install nginx
apt-get update
apt-get install -y nginx apt-transport-https ca-certificates gnupg2

# Install docker
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-engine

# Copy dhparam from gcs
gsutil cp $bucket/dhparam.pem /etc/ssl/dhparam.pem

# Copy ssl certificates from gcs
mkdir -p /etc/ssl/$DOMAIN

# Generate script for syncing certificates with gcs
mkdir -p /opt/scripts
cat << 'EOF' > /opt/scripts/sync-certs.sh
#!/bin/bash

gsutil -m rsync -d -r $bucket/$DOMAIN /etc/ssl/$DOMAIN &> /tmp/sync
lines=$(cat /tmp/sync | grep 'Copying' | wc -l)
if [ "$lines" -gt 0 ]; then
	service nginx restart
fi
EOF

sed -i 's/$DOMAIN/'"$DOMAIN"'/g' /opt/scripts/sync-certs.sh
sed -i 's/$bucket/'"${bucket//\//\\/}"'/g' /opt/scripts/sync-certs.sh
chmod +x /opt/scripts/sync-certs.sh

/opt/scripts/sync-certs.sh

# Add sync certificates as a daily cronjob
sudo crontab -l > /tmp/cron
echo "@daily sleep ${RANDOM:0:2}m ; /opt/scripts/sync-certs.sh &> /var/log/sync-certs.log" >> /tmp/cron
sudo crontab /tmp/cron

# Generate systemd service for application container
cat << EOF > /etc/systemd/system/app.service
[Unit]
Description=App container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStartPre=/usr/bin/docker pull $DOCKER_IMAGE
ExecStart=/usr/bin/docker run -p 3000:$DOCKER_PORT --name app $DOCKER_IMAGE
ExecStop=/usr/bin/docker stop -t 2 app
ExecStopPost=/usr/bin/docker rm -f app

[Install]
WantedBy=default.target
EOF

# Reload systemd and start app service
systemctl daemon-reload
systemctl start app.service &
systemctl enable app.service

# Generate nginx configuration
cat << 'EOF' > /etc/nginx/sites-available/default

# read more here http://tautt.com/best-nginx-configuration-for-security/

# don't send the nginx version number in error pages and Server header
server_tokens off;

# config to don't allow the browser to render the page inside an frame or iframe
# and avoid clickjacking http://en.wikipedia.org/wiki/Clickjacking
# if you need to allow [i]frames, you can use SAMEORIGIN or even set an uri with ALLOW-FROM uri
# https://developer.mozilla.org/en-US/docs/HTTP/X-Frame-Options
add_header X-Frame-Options SAMEORIGIN;

# when serving user-supplied content, include a X-Content-Type-Options: nosniff header along with the Content-Type: header,
# to disable content-type sniffing on some browsers.
# https://www.owasp.org/index.php/List_of_useful_HTTP_headers
# currently suppoorted in IE > 8 http://blogs.msdn.com/b/ie/archive/2008/09/02/ie8-security-part-vi-beta-2-update.aspx
# http://msdn.microsoft.com/en-us/library/ie/gg622941(v=vs.85).aspx
# 'soon' on Firefox https://bugzilla.mozilla.org/show_bug.cgi?id=471020
add_header X-Content-Type-Options nosniff;

# This header enables the Cross-site scripting (XSS) filter built into most recent web browsers.
# It's usually enabled by default anyway, so the role of this header is to re-enable the filter for 
# this particular website if it was disabled by the user.
# https://www.owasp.org/index.php/List_of_useful_HTTP_headers
add_header X-XSS-Protection "1; mode=block";

# SSL server configuration
server {
  listen 443 ssl default deferred;
  listen [::]:443 ssl default deferred;
  server_name $DOMAIN;

  ssl_certificate /etc/ssl/$DOMAIN/fullchain.pem;
  ssl_certificate_key /etc/ssl/$DOMAIN/privkey.pem;

  # enable session resumption to improve https performance
  # http://vincent.bernat.im/en/blog/2011-ssl-session-reuse-rfc5077.html
  ssl_session_cache shared:SSL:50m;
  ssl_session_timeout 5m;

  # Diffie-Hellman parameter for DHE ciphersuites, recommended 2048 bits
  ssl_dhparam /etc/ssl/dhparam.pem;

  # enables server-side protection from BEAST attacks
  # http://blog.ivanristic.com/2013/09/is-beast-still-a-threat.html
  ssl_prefer_server_ciphers on;
  # disable SSLv3(enabled by default since nginx 0.8.19) since it's less secure then TLS http://en.wikipedia.org/wiki/Secure_Sockets_Layer#SSL_3.0
  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  # ciphers chosen for forward secrecy and compatibility
  # http://blog.ivanristic.com/2013/08/configuring-apache-nginx-and-openssl-for-forward-secrecy.html
  ssl_ciphers "EECDH+ECDSA+AESGCM:EECDH+aRSA+AESGCM:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA256:EECDH+ECDSA+SHA384:EECDH+ECDSA+SHA256:EECDH+aRSA+SHA384:EDH+aRSA+AESGCM:EDH+aRSA+SHA256:EDH+aRSA:EECDH:!aNULL:!eNULL:!MEDIUM:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!SEED";

  # enable ocsp stapling (mechanism by which a site can convey certificate revocation information to visitors in a privacy-preserving, scalable manner)
  # http://blog.mozilla.org/security/2013/07/29/ocsp-stapling-in-firefox/
  resolver 8.8.8.8;
  ssl_stapling on;
  ssl_trusted_certificate /etc/ssl/$DOMAIN/fullchain.pem;

  # config to enable HSTS(HTTP Strict Transport Security) https://developer.mozilla.org/en-US/docs/Security/HTTP_Strict_Transport_Security
  # to avoid ssl stripping https://en.wikipedia.org/wiki/SSL_stripping#SSL_stripping
  add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";

  location / {
    # redirect all traffic to localhost:3000
    proxy_pass http://localhost:3000;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header Host $host;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

    # WebSocket support (nginx 1.4)
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
  }
}

# Non secured server configuration
server {
  listen 80;
  listen [::]:80;

  server_name $DOMAIN;

  location /.well-known {
    # redirect acme challenge to letsencrypt renewal server
    proxy_pass http://$letsencrypt;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $remote_addr;
  }
  
  location /_ah/health {
    add_header Content-Type text/plain;
    return 200 'healthy';
  }

  location / {
    # redirect traffic to https
    return 301 https://$server_name$request_uri;
  }
}
EOF

sed -i 's/$DOMAIN/'"$DOMAIN"'/g' /etc/nginx/sites-available/default
sed -i 's/$letsencrypt/'"$letsencrypt"'/g' /etc/nginx/sites-available/default

service nginx restart
