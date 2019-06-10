provider "aws" "aws" {
  region  = "${var.region}"
}

resource "aws_iam_role" "spark_cluster_iam_emr_service_role" {
    name = "spark_cluster_emr_service_role"
 
    assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "elasticmapreduce.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "emr-service-policy-attach" {
   role = "${aws_iam_role.spark_cluster_iam_emr_service_role.id}"
   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceRole"
}

resource "aws_iam_role" "spark_cluster_iam_emr_profile_role" {
    name = "spark_cluster_emr_profile_role"
    assume_role_policy = <<EOF
{
    "Version": "2008-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "profile-policy-attach" {
   role = "${aws_iam_role.spark_cluster_iam_emr_profile_role.id}"
   policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonElasticMapReduceforEC2Role"
}

resource "aws_iam_instance_profile" "emr_profile" {
   name = "spark_cluster_emr_profile"
   role = "${aws_iam_role.spark_cluster_iam_emr_profile_role.name}"
}



resource "aws_security_group" "master_security_group" {
  name        = "master_security_group"
  description = "Allow inbound traffic from VPN"
  vpc_id      = "${var.vpc_id}"

  revoke_rules_on_delete = true
 
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
  }
 
  ingress {
      from_port   = "8443"
      to_port     = "8443"
      protocol    = "TCP"
  }
 
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
 
  ingress {
    from_port   = 8088
    to_port     = 8088
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
 
  ingress {
      from_port   = 18080
      to_port     = 18080
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
 
  ingress {
      from_port   = 8890
      to_port     = 8890
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
  }
 

  ingress {
      from_port   = 4040
      to_port     = 4040
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
  }
 
  ingress {
      from_port   = 80
      to_port     = 80
      protocol    = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
  }
 
  lifecycle {
    ignore_changes = ["ingress", "egress"]
  }

}




resource "aws_security_group" "core_instance_security_group" {
  name        = "core_instance_security_group"
  description = "Allow all internal traffic"
  vpc_id      = "${var.vpc_id}"
  revoke_rules_on_delete = true
 
  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
  }
 
  ingress {
      from_port   = "8443"
      to_port     = "8443"
      protocol    = "TCP"
  }
 
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
 

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/16"]
  }
 
  lifecycle {
    ignore_changes = ["ingress", "egress"]
  }
}

resource "aws_emr_cluster" "emr-spark-cluster" {
   name = "EMR-cluster"
   release_label = "emr-5.9.0"
   applications = ["Ganglia", "Spark", "Zeppelin"]
 
   ec2_attributes {
     instance_profile = "${aws_iam_instance_profile.emr_profile.arn}"
     key_name = "${var.keypair}"
     subnet_id = "${var.subnet_id}"
     emr_managed_master_security_group = "${aws_security_group.master_security_group.id}"
     emr_managed_slave_security_group = "${aws_security_group.core_instance_security_group.id}"
   }
 
   master_instance_group {
    instance_type = "m4.large"
  }

  core_instance_group {
    instance_type  = "m4.large"
    instance_count = 1

    ebs_config {
      size                 = "20"
      type                 = "gp2"
      volumes_per_instance = 1
    }
  }
  bootstrap_action {
    path = "s3://elasticmapreduce/bootstrap-actions/run-if"
    name = "runif"
    args = ["instance.isMaster=true", "echo running on master node"]
  }
 
  service_role = "${aws_iam_role.spark_cluster_iam_emr_service_role.arn}"
}