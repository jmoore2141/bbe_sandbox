# BBE Sandbox web demo

Amazon Linux 2023 t3.micro in us-east-1a, with an encrypted 8 GiB gp3 root disk,
standard CPU credits, and Apache serving **Hello BBE_Sandbox**. One VPC, subnet,
internet gateway and route provide public IPv4 access. No NAT or load balancer.
HTTP (80) and SSH (22) are restricted to the single IPv4 /32 in client_cidr.
Outbound HTTP/HTTPS allow package installation. Resource names ending in private
are retained Terraform addresses from the original demo; the subnet now has an
internet route. Only this instance explicitly requests a public IP.

## Credentials and permissions

Use your existing AWS credentials. Set the expected account ID in terraform.tfvars;
the provider rejects other accounts. The existing demo IAM policy plus
web-demo-additional-policy.json covers the additional network/key operations.
The additional policy grants its listed operations region-wide, not just demo resources.

## Local PEM key

The private key stays in .keys/bbe-sandbox.pem, with mode 600. Only the public key
is imported into AWS; Terraform does not generate or store the private key in state.
.keys/, PEM files, state, local variables, and plans are excluded from Git. Keep
this key secure and backed up; AWS cannot return it later. From a fresh checkout:

```sh
mkdir -p .keys
chmod 700 .keys
ssh-keygen -t rsa -b 3072 -m PEM -N '' -f .keys/bbe-sandbox.pem
chmod 600 .keys/bbe-sandbox.pem
cp terraform.tfvars.example terraform.tfvars
# Edit account ID and client_cidr before planning.
terraform init
terraform plan -out=demo.tfplan
terraform show demo.tfplan
terraform apply demo.tfplan
```

User data installs Apache on first boot; allow time for installation after apply.

## Connect

```sh
cd /Users/joshmoore/github/bbe_sandbox
terraform output -raw web_url
terraform output -raw ssh_command
```

Open the HTTP URL in your browser or run the printed SSH command. The URL is public,
but access is restricted to client_cidr. If your external IP changes, update that
variable and apply. The assigned public IP can change after stopping/starting EC2.
For troubleshooting, SSH and inspect /var/log/cloud-init-output.log and httpd status.

## Cost and cleanup

EC2, EBS and public IPv4 may incur charges; verify credits in AWS Billing.
Destroy after the demo to stop these resource charges:

```sh
terraform plan -destroy -out=destroy.tfplan
terraform show destroy.tfplan
terraform apply destroy.tfplan
```

The root disk is deleted with the instance. Preserve local Terraform state until
cleanup completes. The local PEM remains after destroy. Do not run concurrent applies.
