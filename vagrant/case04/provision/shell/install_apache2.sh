#!/bin/bash   

sudo apt update -y
sudo apt install -y apache2
sudo apt install -y php libapache2-mod-php php-mysql
sudo rm -rf /var/www/html
sudo ln -s /vagrant/html /var/www/html

portsFile='/etc/apache2/ports.conf'
if grep -w '80' $portsFile ; then
    sudo sed -i 's/80/8080/' $portsFile
fi

sudo systemctl reload apache2.service
