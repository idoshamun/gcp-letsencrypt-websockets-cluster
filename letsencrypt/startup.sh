#!/bin/bash

EMAIL=user@domain.com

# Install logging monitor. The monitor will automatically pick up logs sent to
# syslog.
# [START logging]
curl -s "https://storage.googleapis.com/signals-agents/logging/google-fluentd-install.sh" | bash
service google-fluentd restart &
# [END logging]

# Install apache2
apt-get update
apt-get install -y apache2 apt-transport-https ca-certificates gnupg2

# Install docker
apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D
echo "deb https://apt.dockerproject.org/repo debian-jessie main" | sudo tee /etc/apt/sources.list.d/docker.list
apt-get update
apt-get install -y docker-engine

# Remove default apache index page
rm -f /var/www/html/index.html
touch /var/www/html/index.html

# Pull letsencrypt docker image
docker pull quay.io/letsencrypt/letsencrypt:latest

# Create directory for storing certificates and letsencrypt configuration
mkdir /root/ssl
echo "email = $EMAIL" > /root/ssl/cli.ini

# Create renewal script
cat << 'EOF' > /root/renew.sh
#!/bin/bash
domain=$1
docker run -it -v "/root/ssl:/etc/letsencrypt" -v "/var/www/html:/var/www" quay.io/letsencrypt/letsencrypt:latest certonly --webroot -w /var/www -d $domain
bucket=$(curl "http://metadata.google.internal/computeMetadata/v1/project/attributes/certificates-bucket" -H "Metadata-Flavor: Google")
gsutil -m rsync -r /root/ssl/live $bucket
EOF

chmod +x /root/renew.sh
