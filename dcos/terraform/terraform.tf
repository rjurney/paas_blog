# For the time being DCOS Terraform module doesn't support GPUs officially, thus this
# configuration is a working example borrowed from
# https://github.com/dcos-terraform/examples/blob/release/v0.2/aws/gpu-agent/main.tf

provider "aws" {
  region = "us-west-2"
}

resource "random_id" "cluster_name" {
  prefix      = "${var.cluster_prefix}"
  byte_length = 2
}

# Used to determine your public IP for secutiry group rules
data "http" "whatismyip" {
  url = "http://whatismyip.akamai.com/"
}

locals {
  cluster_name        = "${random_id.cluster_name.hex}"
  admin_ips           = [
    "${data.http.whatismyip.body}/32",
    "${compact(split(",", var.extra_admin_ips))}"
  ]

  # GPU instances available in this AZs
  us_west_2_availability_zones = [
    "us-west-2b",
    "us-west-2c",
  ]
}

module "dcos" {
  source                         = "dcos-terraform/dcos/aws"
  version                        = "~> 0.2.6"
  cluster_name                   = "${local.cluster_name}"
  availability_zones             = ["${local.us_west_2_availability_zones}"]
  dcos_superuser_username        = "${var.dcos_superuser_username}"
  dcos_superuser_password_hash   = "${var.dcos_superuser_password_hash}"
  ssh_public_key_file            = "${var.ssh_public_key_file}"
  admin_ips                      = ["${local.admin_ips}"]
  num_masters                    = "${var.num_masters}"
  num_public_agents              = "${var.num_public_agents}"
  public_agents_instance_type    = "${var.cpu_agent_instance_type}"
  private_agents_instance_type   = "${var.gpu_agent_instance_type}"
  num_private_agents             = "${var.num_gpu_agents}"
  dcos_instance_os               = "${var.dcos_instance_os}"
  bootstrap_instance_type        = "${var.bootstrap_instance_type}"
  masters_instance_type          = "${var.master_instance_type}"

  providers = {
    aws = "aws"
  }

  dcos_version                   = "${var.dcos_version}"
  dcos_security                  = "${var.dcos_security}"
  dcos_variant                   = "${var.dcos_variant}"
  dcos_license_key_contents      = "${file(var.dcos_license_key_file)}"

  dcos_master_discovery          = "master_http_loadbalancer"
  dcos_exhibitor_storage_backend = "aws_s3"
  dcos_exhibitor_explicit_keys   = "false"
  with_replaceable_masters       = "true"

  # allow independent allocation of CPUs on GPU instances
  dcos_config = <<EOF
gpus_are_scarce: false
marathon_gpu_scheduling_behavior: unrestricted
metronome_gpu_scheduling_behavior: unrestricted
EOF

  tags = {
    owner = "${var.cluster_owner}"
    expiration = "${var.cluster_expiration}"
  }
}

output "masters-ips" {
  value = "${module.dcos.masters-ips}"
}

output "public-agents-loadbalancer" {
  value = "${module.dcos.public-agents-loadbalancer}"
}