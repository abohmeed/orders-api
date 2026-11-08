variable "region" {
  type    = string
  default = "us-east-1"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "vpc_id" {
  type        = string
  description = "VPC from the S02 baseline."
}

variable "subnet_id" {
  type        = string
  description = "Private subnet from the S02 baseline."
}

variable "ami_id" {
  type        = string
  description = "Amazon Linux AMI for the app host."
}

variable "owner" {
  type    = string
  default = "platform-team"
}

variable "cost_center" {
  type    = string
  default = "dsai-labs"
}
