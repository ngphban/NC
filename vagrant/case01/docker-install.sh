#!/bin/bash

sudo apt-get update -y && sudo apt-get upgrade -y && sudo apt-get autoremove -y
sudo apt-get install curl wget vim -y
sudo curl -fsSL https://get.docker.com | bash
sudo systemctl enable docker
sudo locale-gen pt_BR.UTF-8