# ECS Cluster on EC2

An ECS Cluster based on EC2 instances that runs a nodejs [hello world api](docker pull kornkitti/express-hello-world).

## Push image

Pull hello world image from docker hub

```sh
docker pull kornkitti/express-hello-world
```

Change tag to push it to [ecr](../ecr/README.md)

```sh
docker tag kornkitti/express-hello-world <account_id>.dkr.ecr.<region>.amazonaws.com/<ecr_repo_name>:nodejs-hello-world
```

Get ecr credentials

```sh
aws ecr get-login-password --region eu-central-1 | docker login --username AWS --password-stdin <account_id>.dkr.ecr.<region>.amazonaws.com
```

Push image to ecr

```sh
docker push <account_id>.dkr.ecr.<region>.amazonaws.com/<ecr_repo_name>:nodejs-hello-world
```