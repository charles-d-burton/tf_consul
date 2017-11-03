#Retrieve VPC information

data "aws_vpc" "selected" {
  id = "${var.vpc_id}"
}

data "aws_iam_policy_document" "consul_assume_role_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
      ]
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "consul_instance_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:ListBucket",
    ]

    resources = [
      "${aws_s3_bucket.gaia-tf-consul-backups.arn}",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
    ]

    resources = [
      "${aws_s3_bucket.gaia-tf-consul-backups.arn}/*",
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "route53domains:Get*",
      "route53domains:List*",
      "ec2:DescribeInstances",
      "ec2:DescribeTags",
    ]

    resources = [
      "*",
    ]
  }
}
