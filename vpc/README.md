# VPC

This VPC follows the three-tier application best practice.
It provides three subnets web, computing and data + one addional reserved subnet.

Subnets
* web - public subnet, a place where you can deploy frontend applications
* computing - private subnet, for backend services
* data - private subnet, for dbms + data processing
* reserved - private subnet, additional subnet

All private subnets route to the internet gw through a natgw (1:1 nat gw per AZ, only for `var.environmen` "production")
