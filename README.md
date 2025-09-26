# Simple way to store Terraform state files in AWS s3

## Motivation

I want a simple way to store my `Terraform state` files in `AWS s3`. The solution does not have to be super secure and complicated. Once I have this initial `AWS s3 bucket`, I can improve it later on. Since this is the first `AWS s3 bucket` that would be created in my `AWS` account, it is ok to do some things manually.

## Prerequisites

A Linux or MacOS machine for local development. If you are running Windows, you first need to set up the *Windows Subsystem for Linux (WSL)* environment.

You need `docker cli` and `docker-compose` on your machine for testing purposes, and/or on the machines that run your pipeline.
You can check both of these by running the following commands:
```sh
docker --version
docker-compose --version
```

For `AWS` access you need the following:
- AWS_ACCESS_KEY_ID
- AWS_SECRET_KEY

Already configured `AWS s3 bucket`.

## AWS

First of all, let's create an `AWS s3 bucket`. Navigate to your `AWS` account in the browser (https://0123456789.signin.aws.amazon.com/console) and login; use your `AWS Account-ID` here. Create a `s3 bucket` named for example *my-company-s3-remote-terraform-state-files*. You can use the default settings; make sure you are in the expected region when creating the `s3 bucket`. Let's add a policy to it to deny insecure transport; navigate to *Permissions* tab, Scroll to *Bucket policy* and choose *Edit*; use the following policy:
```sh
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyInsecureTransport",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::aws-sf-home-s3-remote-terraform-state-files",
        "arn:aws:s3:::aws-sf-home-s3-remote-terraform-state-files/*"
      ],
      "Condition": { "Bool": { "aws:SecureTransport": "false" } }
    }
  ]
}
```

Now let's create some access keys so that we can access the `s3 bucket` from Terraform.
In your `AWS` account navigate to *IAM*, afterwards navigate to *Users* and afterwards to *ProgramaticAdmin*; Here you can create an access key; when creating the key, choose *Third-party service*, since the purpose of it is to be used from `Terraform`; the values you obtain here will be used for the AWS_ACCESS_KEY_ID and AWS_SECRET_KEY environment variables.

## Terraform

We will use `docker` containers to run the `Terraform` code. Let's start with the *dockerfile*:
```sh
FROM hashicorp/terraform:1.5.0

ADD ./terraform /app
WORKDIR /app
```
We start from an image that has `Terraform` already preinstalled and afterwards we just copy our code inside.

Now we can crate a *docker-compose* file to run it:
```sh
services:
  update:
    image: test-aws-terraform-state
    network_mode: host
    working_dir: /app
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_KEY=${AWS_SECRET_KEY}
    entrypoint: ["sh", "-c"]
    command: [
      "terraform init && terraform apply -auto-approve"
    ]
  destroy:
    image: test-aws-terraform-state
    network_mode: host
    working_dir: /app
    environment:
      - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
      - AWS_SECRET_KEY=${AWS_SECRET_KEY}
    entrypoint: ["sh", "-c"]
    command: [
      "terraform init && terraform destroy -auto-approve"
    ]
```
Notice that we pass the AWS_ACCESS_KEY_ID and AWS_SECRET_KEY environment variables. The commands just create/update and destroy the `Terraform` infrastructure.

Our `Terraform` code can just contain a file that defines where the state files reside:
```sh
terraform {
  required_version = "1.5.0"
  backend "s3" {
    bucket = "aws-sf-home-s3-remote-terraform-state-files"
    key    = "test-project/terraform.tfstate"
    region = "eu-central-1"
  }
}
```
Note that we use the name of the `AWS s3 bucket` we created earlier. The *region* must also match. Now `Terraform` detects the presence of the AWS_ACCESS_KEY_ID and AWS_SECRET_KEY environment variables and uses them automatically to access the `AWS s3 bucket` defines as *backend*.

## Usage

Now we can create a script to create/update the `Terraform` infrastructure:
```sh
#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

docker build -t test-aws-terraform-state -f docker/dockerfile .
docker-compose -f docker/docker-compose.yml run --rm update
```
, and another one to destroy it:
```sh
#!/bin/sh

# Exit immediately if a simple command exits with a nonzero exit value
set -e

docker build -t test-aws-terraform-state -f docker/dockerfile .
docker-compose -f docker/docker-compose.yml run --rm destroy
```
