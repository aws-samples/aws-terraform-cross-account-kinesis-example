# This defines the EMR Setup for data processing
# It setups all Roles, EC2 parameters, Cluster Setup, VPC, etc.
# THIS CODE IS NOT FOR PRODUCTIVE USE. TEST/TRANING CODE ONLY
# (c) by David Surey - Amazon Web Services EMEA SARL
# 10/2019 - suredavi@amazon.de

# Create an ec2keypair into the processing account. 
# Set via variable. 
resource "aws_key_pair" "ec2key" {
  provider   = aws.processing
  key_name   = var.ec2key
  public_key = var.ec2pubkeystring
}

# Setup the EMR Cluster. Pass attributes for the Nodes and Spark setup
resource "aws_emr_cluster" "cluster" {
  provider      = aws.processing
  name          = "emr-crossaccount-cluster"
  release_label = "emr-5.27.0"
  applications  = ["Spark"]
  ec2_attributes {
    subnet_id                         = aws_subnet.main.id
    emr_managed_master_security_group = aws_security_group.allow_access.id
    emr_managed_slave_security_group  = aws_security_group.allow_access.id
    instance_profile                  = aws_iam_instance_profile.emr_profile.arn
    key_name                          = aws_key_pair.ec2key.key_name
  }
  master_instance_group {
    instance_type = "m5.xlarge"
  }
  core_instance_group {
    instance_type  = "m5.xlarge"
    instance_count = 1
  }
  security_configuration = aws_emr_security_configuration.emr_security.name
  service_role = aws_iam_role.emr_service_role.arn
  configurations_json = <<EOF
  [
    {
      "Classification": "hadoop-env",
      "Configurations": [
        {
          "Classification": "export",
          "Properties": {
            "JAVA_HOME": "/usr/lib/jvm/java-1.8.0"
          }
        }
      ],
      "Properties": {}
    },
    {
      "Classification": "spark-env",
      "Configurations": [
        {
          "Classification": "export",
          "Properties": {
            "JAVA_HOME": "/usr/lib/jvm/java-1.8.0"
          }
        }
      ],
      "Properties": {}
    }
  ]
EOF
}

# setup an security configuration to pass the crossaccountrole to the EMRFS (tbt)
resource "aws_emr_security_configuration" "emr_security" {
  provider = aws.processing
  name = "emr_security"

  configuration = <<EOF
{
  "EncryptionConfiguration": {
    "EnableInTransitEncryption": false,
    "EnableAtRestEncryption": false 
    },
  "AuthorizationConfiguration": {
    "EmrFsConfiguration": 
      {
        "RoleMappings":
          [
            {
             "Role": "arn:aws:iam::${var.account_b}:role/storage_emr_crossaccount_role",
             "IdentifierType": "Prefix","Identifiers": ["direct"]
            }
          ]
      }
  }
}
EOF
}

# Create an security group for the master nodes and allow 22 from 0.0.0.0/0
# PLEASE NOTE: THIS IS FOR FAST TESTING ONLY, OPENING 22 to Anywhere IS NOT SECURE!
resource "aws_security_group" "allow_access" {
  provider    = aws.processing
  name        = "allow_access"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.main.id
  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "TCP"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_subnet.main]
  lifecycle {
    ignore_changes = [
      ingress,
      egress,
    ]
  }
  tags = {
    name = "emr_"
  }
}

# Setup a VPC for the EMR Cluster Nodes.
resource "aws_vpc" "main" {
  provider             = aws.processing
  cidr_block           = "168.31.0.0/16"
  enable_dns_hostnames = true
  tags = {
    name = "emr_"
  }
}

# Setup a subnet for the EMR Cluster Nodes
resource "aws_subnet" "main" {
  provider   = aws.processing
  vpc_id     = aws_vpc.main.id
  cidr_block = "168.31.0.0/20"
  tags = {
    name = "emr_"
  }
}

# Create an internet gateway and attach it to the EMR VPC 
# PLEASE NOTE: THIS IS TO SIMPLIFY THE TESTING ENV. YOU MOST LIKELY DO NOT WANT AN PROD EMR CLUSTER TO HAVE
# DIRECT INTERNET ACCESS. 
resource "aws_internet_gateway" "gw" {
  provider = aws.processing
  vpc_id   = aws_vpc.main.id
}

# Create a (public) route table for the EMR Subnet
resource "aws_route_table" "r" {
  provider = aws.processing
  vpc_id   = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Assoziate the route table to the EMR Node Subnet 
# PLEASE NOTE: THIS IS TO SIMPLIFY THE TESTING ENV. YOU MOST LIKELY DO NOT WANT AN PROD EMR CLUSTER TO HAVE
# DIRECT INTERNET ACCESS. 
resource "aws_main_route_table_association" "a" {
  provider       = aws.processing
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.r.id
}

# Create a service role for the EMR Control Plane
resource "aws_iam_role" "emr_service_role" {
  provider           = aws.processing
  name               = "emr_service_role"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Create a policy for the EMR Cluster Control Plane and attach it to the service role. 
# This Policy grants most likely admin permissions to the EMR Cluster Control plane, not the nodes though. 
# IN AN PRODUCTION ENV YOU SHOULD CONSIDER MORE GRANULAR PERMISSIONS (like predefine s3 buckets for cluster tasks)
resource "aws_iam_role_policy" "emr_service_policy" {
  provider = aws.processing
  name     = "emr_service_policy"
  role     = aws_iam_role.emr_service_role.id
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "ec2:AuthorizeSecurityGroupEgress",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CancelSpotInstanceRequests",
            "ec2:CreateNetworkInterface",
            "ec2:CreateSecurityGroup",
            "ec2:CreateTags",
            "ec2:DeleteNetworkInterface",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteTags",
            "ec2:DescribeAvailabilityZones",
            "ec2:DescribeAccountAttributes",
            "ec2:DescribeDhcpOptions",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeInstances",
            "ec2:DescribeKeyPairs",
            "ec2:DescribeNetworkAcls",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DescribePrefixLists",
            "ec2:DescribeRouteTables",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSpotInstanceRequests",
            "ec2:DescribeSpotPriceHistory",
            "ec2:DescribeSubnets",
            "ec2:DescribeVpcAttribute",
            "ec2:DescribeVpcEndpoints",
            "ec2:DescribeVpcEndpointServices",
            "ec2:DescribeVpcs",
            "ec2:DetachNetworkInterface",
            "ec2:ModifyImageAttribute",
            "ec2:ModifyInstanceAttribute",
            "ec2:RequestSpotInstances",
            "ec2:RevokeSecurityGroupEgress",
            "ec2:RunInstances",
            "ec2:TerminateInstances",
            "ec2:DeleteVolume",
            "ec2:DescribeVolumeStatus",
            "ec2:DescribeVolumes",
            "ec2:DetachVolume",
            "iam:GetRole",
            "iam:GetRolePolicy",
            "iam:ListInstanceProfiles",
            "iam:ListRolePolicies",
            "iam:PassRole",
            "s3:CreateBucket",
            "s3:Get*",
            "s3:List*",
            "sdb:BatchPutAttributes",
            "sdb:Select",
            "sqs:CreateQueue",
            "sqs:Delete*",
            "sqs:GetQueue*",
            "sqs:PurgeQueue",
            "sqs:ReceiveMessage"
        ]
    }]
}
EOF
}

# Create a service role for the EMR integrated jupyter notebook. 
resource "aws_iam_role" "emr_notebook_role" {
  provider           = aws.processing
  name               = "emr_notebook_role"
  assume_role_policy = <<EOF
{
  "Version": "2008-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "elasticmapreduce.amazonaws.com"
      },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": {
          "sts:ExternalId":["${var.account_c}","${var.account_b}"]
        }
      }
    }
  ]
}
EOF
}

# Create a policy for the EMR integrated jupyter notebook service role. 
# Further granular permission control might be wanted. please ref. to the AWS documentation. 
# AS THIS POLICY IS "one permission for all users with notebook/emr access" YOU SHOULD SETUP 
# POLICY/ROLES PER USER/GROUP IN AN PRODUCTIVE ENV
resource "aws_iam_role_policy" "emr_notebook_policy" {
  provider = aws.processing
  name     = "emr_notebook_policy"
  role     = aws_iam_role.emr_notebook_role.id
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "ec2:DescribeSecurityGroups",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNetworkInterfacePermission",
                "ec2:DescribeNetworkInterfaces",
                "ec2:ModifyNetworkInterfaceAttribute",
                "ec2:DescribeTags",
                "ec2:DescribeInstances",
                "ec2:DescribeSubnets",
                "elasticmapreduce:ListInstances",
                "elasticmapreduce:DescribeCluster"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "ec2:CreateTags",
            "Resource": "arn:aws:ec2:*:*:network-interface/*",
            "Condition": {
                "ForAllValues:StringEquals": {
                    "aws:TagKeys": [
                        "aws:elasticmapreduce:editor-id",
                        "aws:elasticmapreduce:job-flow-id"
                    ]
                }
            }
        },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${var.sourcebucket}",
        "arn:aws:s3:::${var.sourcebucket}/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${var.destinationbucket}",
        "arn:aws:s3:::${var.destinationbucket}/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "arn:aws:s3:::aws-emr-resources*",
        "arn:aws:s3:::aws-emr-resources*/*"
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

# Creates an Instance profile for the EC2 instances and attach the Role to it.
resource "aws_iam_instance_profile" "emr_profile" {
  provider = aws.processing
  name     = "emr_profile"
  role     = aws_iam_role.emr_crossaccount_role.name
}

# Create a role for the EMR Cluster instances. This role implies the cross-account access and assume-role permissions
# to change into the S3 Data account
resource "aws_iam_role" "emr_crossaccount_role" {
  provider   = aws.processing
  name               = "emr_crossaccount_role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Create a Policy with the S3 Bucket and assume-role permissions into the S3 Account. 
# Also some default permissions are granted to create logs/etc. 
# YOU SHOULD FUTHER LIMIT ACCESS IN AN PRODUCTIVE ENVIRONMENT. 
resource "aws_iam_role_policy" "emr_crossaccount_policy" {
  provider = aws.processing
  name     = "emr_crossaccount_policy"
  role     = aws_iam_role.emr_crossaccount_role.id
  policy   = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [{
        "Effect": "Allow",
        "Resource": "*",
        "Action": [
            "cloudwatch:*",
            "dynamodb:*",
            "ec2:Describe*",
            "elasticmapreduce:Describe*",
            "elasticmapreduce:ListBootstrapActions",
            "elasticmapreduce:ListClusters",
            "elasticmapreduce:ListInstanceGroups",
            "elasticmapreduce:ListInstances",
            "elasticmapreduce:ListSteps",
            "kinesis:CreateStream",
            "kinesis:DeleteStream",
            "kinesis:DescribeStream",
            "kinesis:GetRecords",
            "kinesis:GetShardIterator",
            "kinesis:MergeShards",
            "kinesis:PutRecord",
            "kinesis:SplitShard",
            "rds:Describe*",
            "s3:*",
            "sdb:*",
            "sns:*",
            "sqs:*"
        ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:PutObjectAcl"
      ],
      "Resource": [
        "arn:aws:s3:::${var.destinationbucket}",
        "arn:aws:s3:::${var.destinationbucket}/*"
      ]
    },
    {
      "Sid": "",
      "Effect": "Allow",
      "Action": "sts:AssumeRole",
      "Resource": [ "arn:aws:iam::${var.account_c}:role/emr_crossaccount_role", 
                    "arn:aws:iam::${var.account_b}:role/storage_emr_crossaccount_role" ]
    }
  ]
}
EOF
}

