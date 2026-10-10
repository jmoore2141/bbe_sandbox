# Private EC2 Terraform demo

Creates one isolated VPC, private subnet, local-only route table and association,
security group with no ingress/egress, and Amazon Linux 2023 EC2 instance in us-east-1.
No public IP, internet gateway, NAT gateway, paid endpoints, key pair, or IAM role.
The instance cannot access the internet or support SSH/SSM sessions in this configuration.
Terraform runs on your computer and uses your computer's AWS connectivity.

## Cost

Default: t3.micro with standard CPU credits (no unlimited surplus-credit charges),
an encrypted 8 GiB gp3 root volume, and no additional disks. Storage is deleted on
termination. This is a small demo, not a guarantee of zero cost. Confirm active
credits/Free Tier coverage in AWS Billing before applying. EC2 and EBS are billed
without coverage; stopping EC2 leaves storage charges, so destroy after the demo.

AWS Free Tier rules: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html

## Plan first

Requires Terraform >= 1.6 and AWS credentials with EC2/VPC read and create/delete
permissions plus ssm:GetParameter for the public AMI parameter. No access keys
belong in this repo. Terraform uses the normal AWS credential chain, including
AWS_PROFILE or AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY (and AWS_SESSION_TOKEN for
session credentials). The AWS CLI is useful for identity checking but isn't
required by Terraform. A CLI profile check must use the same environment/profile
as Terraform.

```sh
cd /Users/joshmoore/github/bbe_sandbox
aws sts get-caller-identity
cp terraform.tfvars.example terraform.tfvars
# Set aws_account_id to your intended account ID in terraform.tfvars.
terraform init
terraform fmt -check
terraform validate
terraform plan -out=demo.tfplan
terraform show demo.tfplan
```

The provider's allowed_account_ids guard rejects the wrong account. Review the
account identity yourself before using its ID. Expect six resources to be added.
Planning reads AWS data but does not deploy infrastructure. Saved plans and state
may contain sensitive information; they are excluded from Git. Commit the provider
lock file. The latest Amazon Linux image is discovered at plan time; a future plan
can propose instance replacement when the image changes.

## Deploy only after reviewing the plan

```sh
terraform apply demo.tfplan
```

## Clean up

```sh
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

State is local. Keep it until destruction completes and do not run simultaneous
Terraform operations. This demo does not create a remote state backend.
