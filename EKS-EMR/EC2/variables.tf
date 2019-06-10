variable "aws_region" {
    type = "string"
    default = "us-east-1"
}

variable "project_name" {
    type = "string"
    default = "migration"
}

variable environment {
    type = "string"
    default = "non-prod"
}

variable team_name {
    type = "string"
    default = "testteam"
}

variable vpc_id {}
variable public_subnet_ids {
    type = "list"
}
variable private_subnet_ids {
    type = "list"
}
variable ami_id {
    type = "string"
}

variable instance_type {
    type = "string"
}

variable root_block_size  {}

variable root_block_type {}

variable keypair_name {}

variable tg_port {
    type = "string"
    default = 80
}

variable tg_enable_stickiness {
    type = "string"
    default = "Yes"
}

variable tg_health_check_interval {
    type = "string"
    default = 300
}
variable tg_health_check_path {
    type = "string"
    default = "/"
}
variable tg_health_check_protocol {
    type = "string"
    default = "HTTP"
}
variable tg_health_check_timeout {
    type = "string"
    default = "5"
}
variable tg_health_check_healthy_threshold {
    type = "string"
    default = 10
}
variable tg_unhealthy_threshold {
    type = "string"
    default = "3"
}
variable tg_matcher {
    type = "string"
    default = 200
}
variable alb_port_http {
    type = "string"
    default = 80
}
variable alb_port_https {
    type = "string"
    default = 443
}
variable alb_protocol_http {
    type = "string"
    default = "HTTP"
}
variable alb_protocol_https {
    type = "string"
    default = "HTTPS"
}
variable alb_ssl_policy {
    type = "string"
    default = "ELBSecurityPolicy-2015-05"
}
variable alb_certificate_arn {}


variable asg_max_size {
    type = "string"
    default = 3
}
variable asg_min_size {
    type = "string"
    default = 1
}
variable asg_desired_capacity {
    type = "string"
    default = 1
}

variable alb_log_bucket_name {}