# This defines the Kinesis Firehow for data ingestion.
# THIS CODE IS NOT FOR PRODUCTIVE USE. TEST/TRANING CODE ONLY
# (c) by David Surey - Amazon Web Services EMEA SARL
# 10/2019 - suredavi@amazon.com


# Create Role for the Firehose delivery into Account B
resource "aws_iam_role" "firehose_crossaccount_role" {
  provider   = aws.ingestion
  name               = "firehose_crossaccount_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": "",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId":["${var.account_a}","${var.account_b}"]
        }
      }
    }
  ]
}
EOF
}

# Create a Policy for the Firehose Role Allowing Upload to the Source Bucket
resource "aws_iam_role_policy" "firehose_crossaccount_role_policy" {
  provider   = aws.ingestion
  name   = "emr_crossaccount_policy"
  role   = aws_iam_role.firehose_crossaccount_role.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${var.sourcebucket}",
        "arn:aws:s3:::${var.sourcebucket}/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [ "arn:aws:iam::${var.account_a}:role/firehose_crossaccount_role" ]
    }
  ]
}
EOF
}

# Create the Kinesis Firehose Delivery Stream for Data ingest
resource "aws_kinesis_firehose_delivery_stream" "delivery_stream" {
  provider   = aws.ingestion
  count       = "1"
  name        = "firehose_stream"
  destination = "s3"
  s3_configuration {
    role_arn        = aws_iam_role.firehose_crossaccount_role.arn
    bucket_arn      = "arn:aws:s3:::${var.sourcebucket}"
    buffer_size     = "5"
    buffer_interval = "60"
    prefix = "direct/"
  }
}