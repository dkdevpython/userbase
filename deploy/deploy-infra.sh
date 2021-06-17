#!/bin/bash

# Generate a personal access token with repo and admin:repo_hook permissions from https://github.com/settings/tokens
ACCESS_TOKEN=$(cat ~/DevOps/access-token)
STACK_NAME=encd
REGION=us-east-1
CLI_PROFILE=userbase
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile $CLI_PROFILE --output text | cut -f1)
CFN_BUCKET="$STACK_NAME-cfn-$AWS_ACCOUNT_ID"
CODEPIPELINE_BUCKET="$STACK_NAME-codepipeline-$AWS_ACCOUNT_ID"
CFORMATION_BUCKET="$STACK_NAME-cformation-$AWS_ACCOUNT_ID"

aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME-setup \
  --template-file ../deploy/cfn/setup.yml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    CodePipelineBucket=$CODEPIPELINE_BUCKET \
    CloudFormationBucket=$CFORMATION_BUCKET

mkdir -p ./deploy/cfn/output

PACKAGE_ERR="$(aws cloudformation package \
  --region $REGION \
  --profile $CLI_PROFILE \
  --template-file ../deploy/cfn/main.yml \
  --s3-bucket $CFORMATION_BUCKET \
  --output-template-file ./deploy/cfn/output/main.yml 2>&1)"

if ! [[ $PACKAGE_ERR =~ "Successfully packaged artifacts" ]]; then
  echo "ERROR while running 'aws cloudformation package' command:"
  echo $PACKAGE_ERR
  exit 1
fi

# Deploy the CloudFormation template
aws cloudformation deploy \
  --region $REGION \
  --profile $CLI_PROFILE \
  --stack-name $STACK_NAME \
  --template-file ./deploy/cfn/output/main.yml \
  --no-fail-on-empty-changeset \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
    GitHubOwner=dkdevpython \
    GitHubRepo=userbase \
    GitHubBranch=master \
    GitHubPersonalAccessToken=$ACCESS_TOKEN \
    EC2StagingInstanceType=t2.micro \
    EC2DemoInstanceType=t2.large \
    EC2AMI=ami-0aeeebd8d2ab47354 \
    Domain=dksaunder.com \
    Certificate=arn:aws:acm:us-east-1:996569927027:certificate/0ffc0e77-1197-4c5b-8ecb-bf6ef110ec30 \
    CodePipelineBucket=$CODEPIPELINE_BUCKET
