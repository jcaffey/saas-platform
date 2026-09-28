resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]
}

resource "aws_iam_role" "github_deploy" {
  name = "saas-platform-dev-github-deploy"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [{
      Effect = "Allow"

      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }

      Action = "sts:AssumeRoleWithWebIdentity"

      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }

        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:jcaffey@599927/saas-platform@1393766225:*"
        }
      }
    }]
  })
}

locals {
  github_deploy_policies = toset([
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonECS_FullAccess",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
    "arn:aws:iam::aws:policy/AmazonSQSFullAccess",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess",
    "arn:aws:iam::aws:policy/AmazonElastiCacheFullAccess",
    "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
    "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  ])
}

resource "aws_iam_role_policy_attachment" "github_deploy" {
  for_each = local.github_deploy_policies

  role       = aws_iam_role.github_deploy.name
  policy_arn = each.value
}

resource "aws_iam_role_policy" "github_terraform_state" {
  name = "terraform-state-access"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = "arn:aws:s3:::saas-platform-tfstate-1234"
      },
      {
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]

        Resource = "arn:aws:s3:::saas-platform-tfstate-1234/dev/terraform.tfstate"
      }
    ]
  })
}
