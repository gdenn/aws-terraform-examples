#!/bin/bash
cw_agent_config_folder=/opt/aws/amazon-cloudwatch-agent/etc/
cw_agent_config_path=/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
cw_agent_ctl=/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl
cw_agent_rpm_download_url=https://s3.eu-central-1.amazonaws.com/amazoncloudwatch-agent-eu-central-1/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm

cw_agent_log_retention=14
cw_agent_collection_interval=60

ssm_agent_deb_download_url=https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb

http_access_logs=/var/log/httpd/access_log
http_error_logs=/var/log/httpd/error_log

export USER=$(whoami)
cd $HOME

#################### AWS SESSION MANAGER AGENT ####################
sudo mkdir /tmp/ssm
cd /tmp/ssm
wget $ssm_agent_deb_download_url

sudo dpkg -i amazon-ssm-agent.deb
sudo systemctl enable amazon-ssm-agent
rm amazon-ssm-agent.deb

#################### CLOUD WATCH AGENT ####################
sudo yum update -y
wget $cw_agent_rpm_download_url
sudo rpm -U ./amazon-cloudwatch-agent.rpm

sudo chown $USER:$USER -R $cw_agent_config_folder
sudo mkdir -p $cw_agent_config_folder
sudo cat <<EOT >> $cw_agent_config_path
{
  "agent": {
    "metrics_collection_interval": $cw_agent_collection_interval,
    "run_as_user": "root"
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "$http_error_logs",
            "log_group_name": "web-server-logs",
            "log_stream_name": "{instance_id}-error-logs",
            "retention_in_days": $cw_agent_log_retention
          },
          {
            "file_path": "$http_access_logs",
            "log_group_name": "web-server-logs",
            "log_stream_name": "{instance_id}-access-logs",
            "retention_in_days": $cw_agent_log_retention
          }
        ]
      }
    }
  },
  "metrics": {
    "aggregation_dimensions": [
      [
        "InstanceId"
      ]
    ],
    "metrics_collected": {
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": $cw_agent_collection_interval,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": $cw_agent_collection_interval
      },
      "statsd": {
        "metrics_aggregation_interval": $cw_agent_collection_interval,
        "metrics_collection_interval": $cw_agent_collection_interval,
        "service_address": ":8125"
      }
    }
  }
}
EOT
sudo $cw_agent_ctl -a fetch-config -m ec2 -c file:$cw_agent_config_path -s

#################### APACHE2 WEB SERVER ####################
sudo amazon-linux-extras install php8.0 mariadb10.5 -y
sudo yum install -y httpd

sudo chown $USER:$USER /var/www/html/index.html
echo “Hello World from $(hostname -f)” > /var/www/html/index.html

sudo systemctl start httpd