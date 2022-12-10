# EC2 Web Server Example

This is a simple architecture that uses a three-tier VPC (@see [vpc-module](../../modules/vpc/README.md)) to deploy an EC2 httpd web server.
The web server is deployed in the computing tier subnet which is private, but can route to the internet through a NAT Gateway.

![./architecture.png](architecture)

An ALB with a target group in front of the EC2 instance in the presentation tier subnet (public subnet) makes the HTTPD service reachable on port 80.

The EC2 instance has a configured cloud watch agent that drains the access and error logs of the httpd service and sends collectd metrics to Cloud Watch.