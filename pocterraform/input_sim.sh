#!/bin/bash
# This script is only used to fire against the Kinesis firehose some random data. 
# using something like ZSH you can use
# "repeat 100 input-sim.sh" to generate a set of data. check with "which repeat" if the command is available for you
aws firehose put-record --delivery-stream-name firehose_stream --record '{"Data":"{\"foo\":\"bar\"}\n"}' --region=eu-central-1 --profile=$1
