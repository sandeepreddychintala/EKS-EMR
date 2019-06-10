
data "aws_elb_service_account" "main" {}
resource "aws_security_group" "ec2-sg" {
  name        = "${var.project_name}-${var.team_name}-${var.environment}-ec2-sg"
  description = "Security group that allows ssh/http and all egress traffic"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = "${var.tg_port}"
    to_port         = "${var.tg_port}"
    protocol        = "tcp"
    security_groups = ["${aws_security_group.alb.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-ec2-sg"
  }
}

resource "aws_launch_configuration" "asg-lc" {
  name_prefix                 = "${var.project_name}-${var.team_name}-${var.environment}-"
  image_id                    = "${var.ami_id}"
  instance_type               = "${var.instance_type}"
  key_name                 = "${var.keypair_name}"
  security_groups             = ["${aws_security_group.ec2-sg.id}"]
}

resource "aws_autoscaling_group" "asg" {
  name                      = "${var.project_name}-${var.team_name}-${var.environment}-asg"
  vpc_zone_identifier       = ["${var.private_subnet_ids}"]
  launch_configuration      = "${aws_launch_configuration.asg-lc.name}"
  min_size                  = "${var.asg_min_size}"
  max_size                  = "${var.asg_max_size}"
  desired_capacity      = "${var.asg_desired_capacity}"
  target_group_arns         = ["${aws_lb_target_group.alb-tg.arn}"]
}

resource "aws_autoscaling_policy" "scaleup" {
  name                   = "${var.project_name}-${var.team_name}-${var.environment}-asp-up"
  autoscaling_group_name = "${aws_autoscaling_group.asg.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scaledown" {
  name                   = "${var.project_name}-${var.team_name}-${var.environment}-asp-down"
  autoscaling_group_name = "${aws_autoscaling_group.asg.name}"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = "-1"
  cooldown               = "300"
  policy_type            = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "up" {
  alarm_name          = "${var.project_name}-${var.team_name}-${var.environment}-alarm-up"
  alarm_description   = "Scales up an instance when CPU utilization is greater than 80%"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"

  dimensions = {
    "AutoScalingGroupName" = "${aws_autoscaling_group.asg.name}"
  }

  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.scaleup.arn}"]
}

resource "aws_cloudwatch_metric_alarm" "down" {
  alarm_name          = "${var.project_name}-${var.team_name}-${var.environment}-alarm-down"
  alarm_description   = "Scales down and instance when CPU utilization is lesser than 50%"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"

  dimensions = {
    AutoScalingGroupName = "${aws_autoscaling_group.asg.name}"
  }

  actions_enabled = true
  alarm_actions   = ["${aws_autoscaling_policy.scaledown.arn}"]
}


resource "aws_security_group" "alb" {
  name        = "${var.project_name}-${var.team_name}-${var.environment}-alb-sg"
  description = "Load Balancer SG"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-alb-sg"
  }
}

resource "aws_lb" "alb" {
  name            = "${var.project_name}-${var.team_name}-${var.environment}-alb"
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${var.public_subnet_ids}"]
  load_balancer_type = "application"
  access_logs {
    bucket  = "${aws_s3_bucket.alb-log-bucket.bucket}"
    prefix  = "alb-logs"
    enabled = true
  }
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-alb"
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = "${var.project_name}-${var.team_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${var.vpc_id}"
  deregistration_delay = 300
  stickiness {
    type              = "lb_cookie"
    cookie_duration   = 86400
    enabled           = "${var.tg_enable_stickiness == "Yes" ? true : false}"
  }
  health_check = {
    interval = "${var.tg_health_check_interval}"
    path = "${var.tg_health_check_path}"
    port = "traffic-port"
    protocol = "${var.tg_health_check_protocol}"
    timeout = "${var.tg_health_check_timeout}"
    healthy_threshold = "${var.tg_health_check_healthy_threshold}"
    unhealthy_threshold = "${var.tg_unhealthy_threshold}"
    matcher             = "${var.tg_matcher}"
  }
}

resource "aws_lb_listener" "alb_listener_http" {
	load_balancer_arn  = "${aws_lb.alb.arn}"
	port               = "${var.alb_port_http}"
	protocol           = "${var.alb_protocol_http}"
	default_action {
        target_group_arn = "${aws_lb_target_group.alb-tg.arn}"
        type             = "forward"
  }
}

resource "aws_lb_listener_rule" "http_rule" {
	listener_arn         = "${aws_lb_listener.alb_listener_http.arn}"
	priority             = 99
	action {
        type              = "forward"
        target_group_arn  = "${aws_lb_target_group.alb-tg.arn}"
  }
  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

resource "aws_lb_listener" "alb_listener_https" {
  load_balancer_arn  = "${aws_lb.alb.arn}"
  port               = "${var.alb_port_https}"
  protocol           = "${var.alb_protocol_https}"
  ssl_policy         = "${var.alb_ssl_policy}"
  certificate_arn    = "${var.alb_certificate_arn}"
  default_action {
    target_group_arn = "${aws_lb_target_group.alb-tg.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "https_rule" {
  listener_arn        = "${aws_lb_listener.alb_listener_https.arn}"
  priority            = 100
  action {
    type              = "forward"
    target_group_arn  = "${aws_lb_target_group.alb-tg.arn}"
  }
  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}
resource "aws_s3_bucket" "alb-log-bucket" {
  bucket = "${var.alb_log_bucket_name}"
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

policy =<<EOF
{
"Id": "Policy1509573454872",
"Version": "2012-10-17",
"Statement": [
    {
    "Sid": "AllowWriteELBLogs",
    "Action": ["s3:PutObject","s3:Get*","s3:List*"],
    "Effect": "Allow",
    "Resource": "arn:aws:s3:::${var.alb_log_bucket_name}/alb-logs/*",
    "Principal": {
        "AWS": ["${data.aws_elb_service_account.main.arn}"]
    }
    }
]
}
EOF
}
