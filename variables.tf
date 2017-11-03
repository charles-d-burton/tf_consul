variable "ami" {
  description = "AWS AMI Id, if you change, make sure it is compatible with instance type, not all AMIs allow all instance types "

  default = {
    us-west-1      = "ami-1c1d217c"
    us-west-2      = "ami-0a00ce72"
    us-east-1      = "ami-da05a4a0"
    us-east-2      = "ami-336b4456"
    sa-east-1      = "ami-466b132a"
    eu-west-1      = "ami-add175d4"
    eu-west-2      = "ami-ecbea388"
    eu-central-1   = "ami-97e953f8"
    ca-central-1   = "ami-8a71c9ee"
    ap-southeast-1 = "ami-67a6e604"
    ap-southeast-2 = "ami-41c12e23"
    ap-south-1     = "ami-bc0d40d3"
    ap-northeast-1 = "ami-15872773"
    ap-northeast-2 = "ami-7b1cb915"
  }
}

variable "availability_zones" {
  /*default     = "us-west-2a,us-west-2b,us-west-2c"*/
  type        = "list"
  description = "List of availability zones, use AWS CLI to find your "
}

variable "private_subnets" {
  /*default = "subnet-b0d839f9,subnet-7698cd2e,subnet-b411ded3"*/
  type        = "list"
  description = "List of subnets to launch instances into"
}

variable "key_name" {}

variable "region" {
  default     = ""
  description = "The region of AWS, for AMI lookups."
}

variable "min_cluster_size" {
  description = "The number of Consul servers to launch."
  default     = 3
}

variable "max_cluster_size" {
  description = "The maximum number of nodes"
  default     = 5
}

variable "instance_type" {
  description = "AWS Instance type, if you change, make sure it is compatible with AMI, not all AMIs allow all instance types "
  default     = "t2.small"
}

variable "tagName" {
  default = "consul-server"
}

variable "vpc_id" {
  description = "VPC to place the cluster in"
}

variable "env" {}

variable "notification_arn" {}
