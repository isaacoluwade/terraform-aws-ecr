data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_policy_document" "repo" {
  for_each = local.repos_with_policy

  dynamic "statement" {
    for_each = length(each.value.cross_account_pull) > 0 ? [1] : []

    content {
      sid    = "CrossAccountPull"
      effect = "Allow"

      principals {
        type = "AWS"
        identifiers = [
          for acct in each.value.cross_account_pull :
          "arn:${data.aws_partition.current.partition}:iam::${acct}:root"
        ]
      }

      actions = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability",
      ]
    }
  }

  dynamic "statement" {
    for_each = length(each.value.cross_account_push) > 0 ? [1] : []

    content {
      sid    = "CrossAccountPush"
      effect = "Allow"

      principals {
        type = "AWS"
        identifiers = [
          for acct in each.value.cross_account_push :
          "arn:${data.aws_partition.current.partition}:iam::${acct}:root"
        ]
      }

      actions = [
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchCheckLayerAvailability",
      ]
    }
  }
}
