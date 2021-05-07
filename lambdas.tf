# This defines the lambda functions used to handle the object permissions in the shared S3 Bucket for source and destination
# THIS CODE IS NOT FOR PRODUCTIVE USE. TEST/TRANING CODE ONLY
# (c) by David Surey - Amazon Web Services EMEA SARL
# 10/2019 - suredavi@amazon.com


######### source bucket lambda construct ##########

# Create the role for the source lambda function
resource "aws_iam_role" "crossiam_for_sourcelambda" {
  name     = "crossiam_for_sourcelambda"
  provider = aws.storage

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${var.account_a}:role/iam_for_sourcelambda" 
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Create the role for the source lambda function which triggers the update of the objectACL
resource "aws_iam_role" "iam_for_sourcelambda" {
  name     = "iam_for_sourcelambda"
  provider = aws.ingestion

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# create the policy to allow the source bucket lambda function to assume the cross-account role and do its job
resource "aws_iam_policy" "sourcelambda_crossaccount" {
  provider      = aws.ingestion
  name = "sourcelambda_crossaccount"
  path = "/"
  description = "IAM policy for Cross Account from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${var.account_b}:role/crossiam_for_sourcelambda",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Attach the Policy to the role for the source bucket lambda function
resource "aws_iam_role_policy_attachment" "sourcelambda-attachment" {
    provider = aws.ingestion
    role = "${aws_iam_role.iam_for_sourcelambda.name}"
    policy_arn = "${aws_iam_policy.sourcelambda_crossaccount.arn}"
}

# create a policy to allow the source bucket lambda function to log into cloudwatch for debugging. 
resource "aws_iam_policy" "sourcelambda_logging" {
  provider      = aws.ingestion
  name = "sourcelambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# attach the policy to the lambda role.
resource "aws_iam_role_policy_attachment" "sourcelambda_logs" {
  provider      = aws.ingestion
  role = "${aws_iam_role.iam_for_sourcelambda.name}"
  policy_arn = "${aws_iam_policy.sourcelambda_logging.arn}"
}

# allow the source bucket to trigger a notification to the source bucket lambda function
resource "aws_lambda_permission" "allow_sourcebucket" {
  provider      = aws.ingestion
  depends_on    = [aws_s3_bucket.sourcebucket]
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sourcefunc.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.sourcebucket.arn
}

# the actual lambda function for the source bucket
resource "aws_lambda_function" "sourcefunc" {
  provider      = aws.ingestion
  filename      = "index.js.zip"
  function_name = "s3-bucket-acl"
  role          = aws_iam_role.iam_for_sourcelambda.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  environment {
    variables = {
      rolearn = "arn:aws:iam::${var.account_b}:role/crossiam_for_sourcelambda"
    }
  }
}

# the actual notification of the source bucket
resource "aws_s3_bucket_notification" "sourcebucket_notification" {
  bucket     = aws_s3_bucket.sourcebucket.id
  provider   = aws.storage
  depends_on = [aws_s3_bucket.sourcebucket]
  lambda_function {
    lambda_function_arn = aws_lambda_function.sourcefunc.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# the policy which prevents the source bucket lambda function to do anything but setting the bucket-owner-full-control for an object. 
resource "aws_iam_policy" "sourcebucketownerpolicy" {
  provider = aws.storage
  name        = "sourcebucketownerpolicy"
  description = "A sourcebucketownerpolicy policy"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObjectAcl",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      },
      "Resource": "arn:aws:s3:::${aws_s3_bucket.sourcebucket.bucket}/*"
    }
  ]
}
EOF
}

# attach the policy to the source bucket lamnbda function
resource "aws_iam_role_policy_attachment" "sourcelamba-attach" {
  provider = aws.storage
  role       = "${aws_iam_role.crossiam_for_sourcelambda.name}"
  policy_arn = "${aws_iam_policy.sourcebucketownerpolicy.arn}"
}

######### destination bucket lambda construct ##########

# Create the role for the destination lambda function
resource "aws_iam_role" "iam_for_destinationlambda" {
  name     = "iam_for_destinationlambda"
  provider = aws.processing

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# Create the cross-account role for the destination in account b
resource "aws_iam_role" "crossiam_for_destinationlambda" {
  name     = "crossiam_for_destinationlambda"
  provider = aws.storage
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "AWS": "arn:aws:iam::${var.account_c}:role/iam_for_destinationlambda" 
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# the policy allowing access and role-assume for the destination bucket lambda function
resource "aws_iam_policy" "destinationlambda_crossaccount" {
  provider      = aws.processing
  name = "destinationlambda_crossaccount"
  path = "/"
  description = "IAM policy for Cross Account from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Resource": "arn:aws:iam::${var.account_b}:role/crossiam_for_destinationlambda",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# attach the policy to the actual destination lambda role
resource "aws_iam_role_policy_attachment" "destinationlambda-attachment" {
    provider  = aws.processing
    role = "${aws_iam_role.iam_for_destinationlambda.name}"
    policy_arn = "${aws_iam_policy.destinationlambda_crossaccount.arn}"
}


# allow the destination bucket lambda function to create logstreams and logs in cloudwatch
resource "aws_iam_policy" "destinationlambda_logging" {
  provider      = aws.processing
  name = "destinationlambda_logging"
  path = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

# attach the log policy to the destination bucket role
resource "aws_iam_role_policy_attachment" "destinationlambda_logs" {
  provider      = aws.processing
  role = "${aws_iam_role.iam_for_destinationlambda.name}"
  policy_arn = "${aws_iam_policy.destinationlambda_logging.arn}"
}

# allow the destination bucket to send notifies to the destination bucket function
resource "aws_lambda_permission" "allow_destinationbucket" {
  provider      = aws.processing
  depends_on    = [aws_s3_bucket.destinationbucket]
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.destinationfunc.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.destinationbucket.arn
}

# the actual function for the destination bucket
resource "aws_lambda_function" "destinationfunc" {
  provider      = aws.processing
  filename      = "index.js.zip"
  function_name = "s3-bucket-acl"
  role          = aws_iam_role.iam_for_destinationlambda.arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  environment {
    variables = {
      rolearn = "arn:aws:iam::${var.account_b}:role/crossiam_for_destinationlambda"
    }
  }
}

# the notification for the lambda function from the destinaton bucket. 
resource "aws_s3_bucket_notification" "destinationbucket_notification" {
  provider   = aws.storage
  depends_on = [aws_s3_bucket.destinationbucket]
  bucket     = aws_s3_bucket.destinationbucket.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.destinationfunc.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

# make sure that the destination bucket function is only allowed to set the bucket-owner-full-control ACL
resource "aws_iam_policy" "destinationbucketownerpolicy" {
  provider = aws.storage
  name        = "destinationbucketownerpolicy"
  description = "A destinationbucketownerpolicy policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:PutObjectAcl",
      "Condition": {
        "StringEquals": {
          "s3:x-amz-acl": "bucket-owner-full-control"
        }
      },
      "Resource": "arn:aws:s3:::${aws_s3_bucket.destinationbucket.bucket}/*"
    }
  ]
}
EOF
}

# attach the policy to the destination function bucket role
resource "aws_iam_role_policy_attachment" "destinationlamba-attach" {
  provider = aws.storage
  role       = "${aws_iam_role.crossiam_for_destinationlambda.name}"
  policy_arn = "${aws_iam_policy.destinationbucketownerpolicy.arn}"
}
