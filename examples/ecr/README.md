# ECR Repo

This stack contains an ECR repository that you can use to store container images.

The images can be accessed from an ECS task role or through different push/pull IAM user groups.

## How To use the ECR

Get ECR credentials

```sh
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
```