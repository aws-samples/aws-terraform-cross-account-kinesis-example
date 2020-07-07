# This defines the EMR Setup for data processing
# It setups all Buckets, Account B Roles and Bucket Policies needed. 
# THIS CODE IS NOT FOR PRODUCTIVE USE. TEST/TRANING CODE ONLY
# (c) by David Surey - Amazon Web Services EMEA SARL
# 10/2019 - suredavi@amazon.de

# Create the Source files bucket
resource "aws_s3_bucket" "sourcebucket" {
  provider = aws.storage
  bucket   = "${var.sourcebucket}"
}

# Create the Destination files bucket
resource "aws_s3_bucket" "destinationbucket" {
  provider = aws.storage
  bucket   = "${var.destinationbucket}"
}

# Create the role to be assumed by the jupyter notebooks
resource "aws_iam_role" "storage_emr_notebook_role" {
  name     = "storage_emr_notebook_role"
  provider = aws.storage
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${var.account_c}:role/emr_notebook_role" 
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# create a policy attached to the role. Limit the role to read only from the source bucket
resource "aws_iam_policy" "storage_emr_notebook_policy" {
  provider = aws.storage
  name        = "storage_emr_notebook_policy"
  description = "A storage_emr_notebook_policy policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ 
                "s3:GetObject",
                "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}/*",
        "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [ "arn:aws:iam::${var.account_c}:role/emr_notebook_role", 
                    "arn:aws:iam::${var.account_b}:role/storage_emr_notebook_role" ]
    }
  ]
}
EOF
}

# Attach the created policy to the role for the jupyter notebook.
resource "aws_iam_role_policy_attachment" "crosspolicy-for-notebook-attach" {
  provider = aws.storage
  role       = "${aws_iam_role.storage_emr_notebook_role.name}"
  policy_arn = "${aws_iam_policy.storage_emr_notebook_policy.arn}"
} 

# create the cross-account role for the EMR EC2 instances. 
resource "aws_iam_role" "storage_emr_crossaccount_role" {
  name     = "storage_emr_crossaccount_role"
  provider = aws.storage
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${var.account_c}:role/emr_crossaccount_role" 
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Create the related Policy and ...‚
resource "aws_iam_policy" "storage_emr_crossaccount_policy" {
  provider = aws.storage
  name        = "storage_emr_crossaccount_policy"
  description = "A storage_emr_crossaccount_policy policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [ 
                "s3:GetObject",
                "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}/*",
        "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [ "arn:aws:iam::${var.account_c}:role/emr_crossaccount_role", 
                    "arn:aws:iam::${var.account_c}:role/storage_emr_crossaccount_role" ]
    }
  ]
}
EOF
}

# ... attach that policy to the EMR EC2 node cross-account role. 
resource "aws_iam_role_policy_attachment" "crosspolicy-for-emr-attach" {
  provider = aws.storage
  role       = "${aws_iam_role.storage_emr_crossaccount_role.name}"
  policy_arn = "${aws_iam_policy.storage_emr_crossaccount_policy.arn}"
}

# Create the policy document for the Bucket Policy of the source bucket
data "aws_iam_policy_document" "b" {
  provider = aws.storage
  depends_on = [
    "aws_iam_role.firehose_crossaccount_role",
    "aws_iam_role.storage_emr_crossaccount_role",
    "aws_iam_role.storage_emr_notebook_role"
  ]
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.account_a}:role/firehose_crossaccount_role"
      ]
    }
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}/*",
    ]
  }
  statement {
    sid    = "2"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.account_b}:role/storage_emr_crossaccount_role",
        "arn:aws:iam::${var.account_b}:role/storage_emr_notebook_role"
      ]
    }
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}/*",
    ]
  }
}

# Attach the policy document to the actual policy for the source bucket. 
resource "aws_s3_bucket_policy" "b" {
  provider = aws.storage
  depends_on = [
    "aws_iam_role.firehose_crossaccount_role",
    "aws_iam_role.storage_emr_crossaccount_role",
    "aws_iam_role.storage_emr_notebook_role"
  ]
  bucket = aws_s3_bucket.sourcebucket.bucket
  policy = data.aws_iam_policy_document.b.json
}

# Create the policy document for the Bucket Policy of the destination bucket
data "aws_iam_policy_document" "c" {
  provider = aws.storage
  depends_on = [
    "aws_iam_role.emr_crossaccount_role",
    "aws_iam_role.emr_notebook_role",
    "aws_iam_role.storage_emr_crossaccount_role",
    "aws_iam_role.storage_emr_notebook_role"
  ]
  statement {
    sid    = "1"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.account_c}:role/emr_crossaccount_role",
        "arn:aws:iam::${var.account_b}:role/storage_emr_crossaccount_role"
      ]
    }
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:PutObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.destinationbucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.destinationbucket.bucket}/*",
    ]
  }
  statement {
    sid    = "2"
    effect = "Allow"
    principals {
      type = "AWS"
      identifiers = [
        "arn:aws:iam::${var.account_c}:role/emr_notebook_role",
        "arn:aws:iam::${var.account_b}:role/storage_emr_notebook_role"
      ]
    }
    actions = [
      "s3:ListBucket",
      "s3:PutObject",
      "s3:GetObject",      
      "s3:PutObjectAcl"
    ]
    resources = [
      "arn:aws:s3:::${aws_s3_bucket.destinationbucket.bucket}",
      "arn:aws:s3:::${aws_s3_bucket.destinationbucket.bucket}/*",
    ]
  }
}

# Attach the policy document to the actual policy for the destination bucket. 
resource "aws_s3_bucket_policy" "c" {
  provider = aws.storage
  depends_on = [
    "aws_iam_role.emr_crossaccount_role",
    "aws_iam_role.emr_notebook_role"
  ]
  bucket = aws_s3_bucket.destinationbucket.bucket
  policy = data.aws_iam_policy_document.c.json
}
