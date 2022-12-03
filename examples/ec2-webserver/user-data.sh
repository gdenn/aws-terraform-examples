#!/bin/bash

#################### AWS SESSION MANAGER AGENT ####################
sudo mkdir /tmp/ssm
cd /tmp/ssm
wget https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb

sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
rm amazon-ssm-agent.deb

#################### APACHE2 WEB SERVER ####################
sudo yum update -y
sudo amazon-linux-extras install php8.0 mariadb10.5 -y
sudo yum install -y httpd

user=$(whoami)
sudo chown $user:$user /var/www/html/index.html
echo “Hello World from $(hostname -f)” > /var/www/html/index.html