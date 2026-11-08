# terraform-aws-ec2

Creates a complete, minimal public environment on AWS: a VPC with one public subnet and an Internet Gateway, plus a single Amazon Linux 2023 EC2 instance in that subnet. The instance's security group allows SSH **only from the public IP of the machine running Terraform**.

## Resources

### Network

| Resource | Name tag | Notes |
|----------|----------|-------|
| `aws_vpc.this` | `<project>-<env>-vpc` | DNS support and DNS hostnames enabled |
| `aws_internet_gateway.this` | `<project>-<env>-igw` | Attached to the VPC |
| `aws_subnet.public` | `<project>-<env>-public-subnet` | Placed in the first available AZ; `map_public_ip_on_launch = true` |
| `aws_route_table.public` | `<project>-<env>-public-rt` | Default route `0.0.0.0/0` → Internet Gateway |
| `aws_route_table_association.public` | – | Associates the public subnet with the public route table |

### Compute

| Resource | Name tag | Notes |
|----------|----------|-------|
| `aws_security_group.ssh` | `<project>-<env>-ssh-sg` | Created in the module's VPC |
| `aws_vpc_security_group_ingress_rule.ssh` | – | TCP 22 from `<your-public-ip>/32` |
| `aws_vpc_security_group_egress_rule.all` | – | All protocols to `0.0.0.0/0` |
| `aws_instance.this` | `<project>-<env>-ec2` | Latest AL2023 x86_64 AMI in the public subnet; IMDSv2 required (`http_tokens = "required"`) |

### Data sources

- **`aws_availability_zones.available`** picks the AZ for the subnet (`names[0]`).
- **`aws_ami.al2023`** finds the most recent Amazon-owned AMI that matches `al2023-ami-2023.*-x86_64` in the provider's region, so there's no AMI ID to hardcode.
- **`http.my_ip`** calls `https://checkip.amazonaws.com` to get the caller's public IP. A postcondition stops the run with an error if the response isn't HTTP 200.

```
Internet ── IGW ── VPC (vpc_cidr)
                    └── Public subnet (public_subnet_cidr, AZ[0])
                          route 0.0.0.0/0 → IGW
                          └── EC2 (AL2023) + SG: 22/tcp from <your-ip>/32
```

## Usage

```hcl
module "ec2" {
  source  = "selormharry-png/ec2/aws"
  version = "1.0.2"

  project_name       = "module-training"
  environment        = "dev"
  vpc_cidr           = "10.0.0.0/16"
  public_subnet_cidr = "10.0.1.0/24"
  instance_type      = "t3.micro"
  key_name           = "my-key-pair"
}
```

## Inputs

| Name | Type | Default | Required | Description |
|------|------|---------|:--------:|-------------|
| `project_name` | `string` | – | yes | Prefix used in resource `Name` tags |
| `environment` | `string` | – | yes | Environment name used in `Name` tags, e.g. `dev` |
| `vpc_cidr` | `string` | – | yes | CIDR block for the VPC, e.g. `10.0.0.0/16` |
| `public_subnet_cidr` | `string` | – | yes | CIDR block for the public subnet; must be inside `vpc_cidr` |
| `instance_type` | `string` | – | yes | EC2 instance type, e.g. `t3.micro` (must be x86_64 to match the AMI) |
| `key_name` | `string` | `null` | no | Name of an existing EC2 key pair. If you leave it `null`, the instance has no key pair and you can't SSH into it. |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | ID of the VPC |
| `public_subnet_id` | ID of the public subnet |
| `instance_id` | ID of the EC2 instance |
| `instance_public_ip` | Public IPv4 address of the instance |
| `security_group_id` | ID of the SSH security group |
| `ssh_command` | `ssh -i <path-to-your-key>.pem ec2-user@<public-ip>`. Replace the key path with yours. |

## Requirements

| Name | Version |
|------|---------|
| Terraform | `>= 1.5.0` |
| `hashicorp/aws` | `~> 6.0` |
| `hashicorp/http` | `~> 3.0` |

The module has no `provider` blocks. It uses the providers configured by the caller, including the region and any `default_tags`.

## Notes

- **The SSH source IP is looked up on every plan.** If your public IP changes (a different network, a VPN, or running from CI), the next `apply` updates the ingress rule to the new IP and the old one loses access.
- **The AMI can change.** When Amazon publishes a newer AL2023 AMI, `plan` will show the instance being **replaced**. To avoid that, pin the AMI, or add `lifecycle { ignore_changes = [ami] }` to the instance.
- **Architecture:** the AMI filter is x86_64-only, so Graviton (ARM) instance types like `t4g.*` won't work unless you change the filter.
- **Single AZ, single public subnet.** This module is meant for learning and small test setups. It has no private subnets, no NAT gateway, and no multi-AZ redundancy.
- **Login user:** Amazon Linux uses `ec2-user`.
