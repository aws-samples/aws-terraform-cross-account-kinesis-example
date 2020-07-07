variable "region" {
  description = "Deployment Region"
}

variable "profile_ingestion" {
  description = "Profile of Kinesis Firehose Account"
}

variable "profile_storage" {
  description = "Profile of S3 Account"
}

variable "profile_processing" {
  description = "Profile of EMR Account"
}

variable "ec2key" {
  description = "EC2 SSH Key Name"
}
variable "ec2pubkeystring" {
  description = "EC2 SSH Key Name"
}

variable "account_a" {
  description = "AWS Firehose Account ID"
}

variable "account_b" {
  description = "AWS S3 Account ID"
}

variable "account_c" {
  description = "AWS EMR Account ID"
}

variable "sourcebucket" {
  description = "AWS Firehose Bucket Name"
}

variable "destinationbucket" {
  description = "AWS EMR Destination Bucket"
}

