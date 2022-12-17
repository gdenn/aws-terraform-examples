#####################################################
# ECR REPOSITORY
#####################################################

resource "aws_ecr_repository" "ecr" {
  name = "shared-ecr"
  image_tag_mutability = "MUTABLE" # allow overrides of the LATEST tag
  tags = {
    Name = "shared-ecr"
    Environment = "test"
  }
}

resource "aws_ecr_lifecycle_policy" "ecr_lifecycle_policy" {
  repository = aws_ecr_repository.ecr.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description = "keep only the last 10 images"
      actions = {
        type = "expire"
      }
      selection = {
        tagStatus = "any"
        countType = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
}


#####################################################
# PULLING IMAGES
#####################################################

resource "aws_iam_role" "ecr_pull_role" {
  name = "ecr-pull-role"
  assume_role_policy = data.aws_iam_policy_document.ecr_trust_policy.json
}

resource "aws_iam_group" "ecr_pull_group" {
  name = "ecr_pull_group"
}

resource "aws_iam_policy_attachment" "attach_ecr_read_only" {
  name = "attach_ecr_read_only"
  roles = [aws_iam_role.ecr_pull_role.name]
  groups = [aws_iam_group.ecr_pull_group.name]
  policy_arn = data.aws_iam_policy.ecr_read_only.arn
}

data "aws_iam_policy" "ecr_read_only" {
  arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

#####################################################
# PUSHING IMAGES
#####################################################

resource "aws_iam_role" "ecr_push_role" {
  name = "ecr-push-role"
  assume_role_policy = data.aws_iam_policy_document.ecr_trust_policy.json
}

resource "aws_iam_group" "ecr_push_group" {
  name = "ecr_push_group"
}


resource "aws_iam_policy_attachment" "attach_ecr_write_only" {
  name = "attach_ecr_write_only"
  roles = [aws_iam_role.ecr_push_role.name]
  groups = [aws_iam_group.ecr_push_group.name]
  policy_arn = aws_iam_policy.ecr_write_only_policy.arn
}

resource "aws_iam_policy" "ecr_write_only_policy" {
  name = "ecr_write_only_policy"
  policy = data.aws_iam_policy_document.ecr_write_only_policy.json
}

data "aws_iam_policy_document" "ecr_trust_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    effect = "Allow"

    principals {
      type = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "ecr_write_only_policy" {
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:PutImage",
      "ecr:GetAuthorizationToken"
    ]
    effect = "Allow"
    resources = [aws_ecr_repository.ecr.arn]
  }
}

