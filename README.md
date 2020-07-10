# Example 3-Account Data Pipeline 

* ## Description of the Example 

* ## Prerequisites 
  * ### credential Setup
  be sure to setup profiles for each of the accounts you want to place parts of the pipeline. 
  you'll need admin access in each of them. setup the accounts using ~/.aws/config and ~/.aws/credentials
  on the device you're planning to run the terraform from

  * ### Terraform Setup
  install terraform like: https://learn.hashicorp.com/terraform/getting-started/install.html 
  download from here: https://www.terraform.io/downloads.html 
  Terraform is licences under MPL-2.0, please refer to https://github.com/hashicorp/terraform for further information

  * ### Init for deployment
  run: terraform init
  * ### Variables
  look into example.rtfvar and set the variables as needed. 
  * ### Deployment
  run: terraform plan --var-file ./example.tfvar
  if gone through w/o error
  run: terraform apply --var-file ./example.tfvar
  * ### Testing
  run: the script "input_sim.sh" 
  you will need to pass the profile to the profile used for your ingestion
    you can use  the "repeat" program for instance to rerun the command several times to fill up the firebase queue. (or just run multible times)

```
repeat 100 ./input_sim.sh PROFILE_ACCOUNT_A
```


successful looks like: 
  ```
}
{
    "RecordId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
    "Encrypted": false
}
  ```

  log into the EMR Cluster Master (look into Management Console or via CLI for the DNS name) using your SSH key used for the environment

  vi .aws/config 
add your role_arns like: 

```
[default]
region = eu-central-1 

[profile default]
role_arn = arn:aws:iam::ACCOUNT_B_ID:role/storage_emr_crossaccount_role
credential_source = Ec2InstanceMetadata

[profile local]
role_arn = arn:aws:iam::ACCOUNT_A_ID:role/emr_crossaccount_role
credential_source = Ec2InstanceMetadata
```
then you can list and access the S3 Bucket:

```
aws s3 ls s3://sourcesfromexamplefirehose/direct
```

or copy an object to local like: 
```
aws s3 cp s3://sourcesfromexamplefirehose/direct/PATH/TO/OBJECT/ .
```

  * ### Cleanup
  run: terraform destroy --var-file ./example.tfvar
  note: if you get errors from an non-empty bucket ... you should know what you do (in case: delete first all objects manualle ... or the whole bucket ..) :) 

  * ### Troubleshooting / Common Errors
  'Error: Missing required argument
  The argument "region" is required, but was not set.'
  -> Can be ignored.

  Error: you get something like "cannot assume-role" or "No creds in EC2InstanceMetadata" 
  Run! 

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

Terraform is licences under MPL-2.0, please refer to https://github.com/hashicorp/terraform for further information