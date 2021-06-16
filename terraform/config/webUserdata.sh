#!/bin/sh
# Install nginx
apt-get -y update
apt-get -y install nginx
export LOCAL_IPV4=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4/)
echo This is server $LOCAL_IPV4 > /var/www/html/index.nginx-debian.html
