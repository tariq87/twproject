variable "aws_region" {}
variable "profile" {}
data "aws_availability_zones" "available" {}
variable "vpc_cidr" {}

variable "cidrs" {
  type = "map"
}
variable "asg_max" {}
variable "asg_min" {}
variable "asg_cap" {}
variable "asg_grace" {}
variable "asg_hct" {}
variable "lc_instance_type" {}
variable "localip" {}
variable "domain_name" {}
variable "dev_instance_type" {}
variable "dev_ami" {}
variable "public_key_path" {}
variable "key_name" {}
variable "elb_healthy_threshold" {}
variable "elb_unhealthy_threshold" {}
variable "elb_timeout" {}
variable "elb_interval" {}
variable "time" {}
