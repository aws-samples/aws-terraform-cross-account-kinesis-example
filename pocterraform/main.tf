# This defines the Providers we will use for the 3 Accounts
# the profiles used are setup within ~/.aws/credentials 
# THIS CODE IS NOT FOR PRODUCTIVE USE. TEST/TRANING CODE ONLY
# (c) by David Surey - Amazon Web Services EMEA SARL
# 10/2019 - suredavi@amazon.com

provider "aws" {
  alias   = "ingestion"
  version = "~> 2.0"
  region  = "${var.region}"
  profile = "${var.profile_ingestion}"
}

provider "aws" {
  alias   = "storage"
  version = "~> 2.0"
  region  = "${var.region}"
  profile = "${var.profile_storage}"
}

provider "aws" {
  alias   = "processing"
  version = "~> 2.0"
  region  = "${var.region}"
  profile = "${var.profile_processing}"
}