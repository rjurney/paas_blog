variable "cluster_prefix" {
  type    = "string"
  default = "jupyter-gpu-"
}

variable "dcos_variant" {
  type    = "string"
  default = "ee"
}

variable "dcos_license_key_file" {
  type    = "string"
  default = "./license.txt"
}

variable "dcos_version" {
  type    = "string"
  default = "1.13.0"
}

variable "dcos_security" {
  type    = "string"
  default = "permissive"
}

variable "dcos_instance_os" {
  type    = "string"
  default = "centos_7.5"
}

variable "bootstrap_instance_type" {
  type    = "string"
  default = "m5.large"
}

variable "master_instance_type" {
  type    = "string"
  default = "m5.xlarge"
}

variable "num_masters" {
  type    = "string"
  default = "1"
}

variable "num_public_agents" {
  type    = "string"
  default = "1"
}

variable "num_gpu_agents" {
  type    = "string"
  default = "5"
}

variable "cpu_agent_instance_type" {
  type    = "string"
  default = "m5.xlarge"
}

variable "gpu_agent_instance_type" {
  type    = "string"
  default = "p2.xlarge"
}

variable "dcos_superuser_username" {
  type    = "string"
}

variable "dcos_superuser_password_hash" {
  type    = "string"
}

variable "ssh_public_key_file" {
  type    = "string"
  default = "~/.ssh/id_rsa.pub"
}

variable "cluster_expiration" {
  type    = "string"
  default = "3h"
}

variable "cluster_owner" {
  type    = "string"
}

variable "extra_admin_ips" {
  type    = "string"
  default = ""
}
