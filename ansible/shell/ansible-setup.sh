#!/bin/bash

# install ansible
yum -y install http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
yum -y install ansible

# install boto3 module for Ansible
yum -y install python-pip
pip install boto boto3

# Set less ssh key less permissive
cd /home/vagrant/provision/aws
chmod 600 myrdr66.pem

# Run your playbooks
# ansible-playbook playbooks/environment.yml