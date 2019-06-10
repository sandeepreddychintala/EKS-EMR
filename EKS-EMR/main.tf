provider "aws" {
  region = "${var.aws_region}"
}

module "vpc" {
    source = "./VPC"
    project_name = "${var.project_name}"
    environment = "${var.environment}"
    team_name = "${var.team_name}"
}

module "ec2" {
    source = "./EC2"
    project_name = "${var.project_name}"
    environment = "${var.environment}"
    team_name = "${var.team_name}"

    vpc_id = "${module.vpc.vpc-id}"
    public_subnet_ids = "${module.vpc.public_subnet_ids}"
    private_subnet_ids = "${module.vpc.private_subnet_ids}"
    
    ami_id = "ami-0c6b1d09930fac512"
    instance_type = "t2.micro"
    root_block_size = "8"
    root_block_type = "gp2"
    keypair_name = "testkeypair"
    
    tg_port = "80"
    tg_enable_stickiness = "Yes"
    tg_health_check_interval = 300
    tg_health_check_path = "/"
    tg_health_check_protocol = "HTTP"
    tg_health_check_timeout = 3
    tg_health_check_healthy_threshold = 10
    tg_unhealthy_threshold = 3
    tg_matcher = 200

    alb_port_http = 80
    alb_port_https = 443
    alb_protocol_http = "HTTP"
    alb_protocol_https = "HTTPS"
    alb_ssl_policy = "ELBSecurityPolicy-2015-05"
    alb_certificate_arn = "arn:aws:acm:us-east-1:586161092036:certificate/21601b14-1ae3-469c-8b17-1554d9646c04"
    alb_log_bucket_name = "test-s3bucket-for-alb-logs-on-my-account-23"

    asg_max_size = 2
    asg_min_size = 1
    asg_desired_capacity = 1
}

module "eks" {
    source = "./EKS"
    project_name = "${var.project_name}"
    environment = "${var.environment}"
    team_name = "${var.team_name}"
    vpc_id = "${module.vpc.vpc-id}"
    public_subnet_ids = "${module.vpc.public_subnet_ids}"
    private_subnet_ids = "${module.vpc.private_subnet_ids}"
    instance_type = "m4.large"
}