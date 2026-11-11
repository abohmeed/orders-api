# GitHub Actions OIDC trust for pull requests only; plan (read) access.
# Fill locals.github_repo (owner/name) and account before apply.

locals {
  github_repo   = "abohmeed/orders-api" # demo repo for this course
  github_org    = "abohmeed"
  aws_region    = var.aws_region
  oidc_provider = "token.actions.githubusercontent.com"
}

data "aws_caller_identity" "current" {}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://${local.oidc_provider}"
}

data "aws_iam_policy_document" "agent_assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Trust only this repository, and only pull_request events.
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_provider}:sub"
      values = [
        "repo:${local.github_repo}:pull_request",
      ]
    }
  }
}

resource "aws_iam_role" "gha_agent_plan" {
  name               = "${var.project}-gha-agent-plan"
  assume_role_policy = data.aws_iam_policy_document.agent_assume.json
}

data "aws_iam_policy_document" "agent_plan_only" {
  statement {
    sid    = "ReadAndPlanOnly"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "iam:Get*",
      "iam:List*",
      "s3:Get*",
      "s3:List*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "gha_agent_plan" {
  name   = "plan-read-only"
  role   = aws_iam_role.gha_agent_plan.id
  policy = data.aws_iam_policy_document.agent_plan_only.json
}

output "agent_plan_role_arn" {
  value = aws_iam_role.gha_agent_plan.arn
}
