provider "aws" {
  region = "${var.region}"
}
data "aws_region" "current" {}


resource "aws_iam_role" "eks-cluster-role" {
  name = "${var.project_name}-${var.team_name}-${var.environment}-eks-cluster-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["eks.amazonaws.com", "ec2.amazonaws.com]"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = "${aws_iam_role.eks-cluster-role.name}"
}

resource "aws_iam_role_policy_attachment" "cluster-AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = "${aws_iam_role.eks-cluster-role.name}"
}

resource "aws_security_group" "eks-sg" {
  name        = "${var.project_name}-${var.team_name}-${var.environment}-eks-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = "${var.vpc_id}"
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-eks-sg"
  }
}

resource "aws_security_group_rule" "ingress-node-https" {
  description              = "Allow pods to communicate with the cluster API Server"
  from_port                = 443
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.eks-sg.id}"
  source_security_group_id = "${aws_security_group.worker-node-sg.id}"
  to_port                  = 443
  type                     = "ingress"
}

resource "aws_security_group_rule" "ingress-workstation-https" {
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow workstation to communicate with the cluster API Server"
  from_port         = 443
  protocol          = "tcp"
  security_group_id = "${aws_security_group.eks-sg.id}"
  to_port           = 443
  type              = "ingress"
}

resource "aws_eks_cluster" "eks-cluster" {
  name     = "${var.project_name}-${var.team_name}-${var.environment}-eks-cluster"
  role_arn = "${aws_iam_role.eks-cluster-role.arn}"

  vpc_config {
    security_group_ids = ["${aws_security_group.eks-sg.id}"]
    subnet_ids         = ["${var.public_subnet_ids}"]
    endpoint_private_access = "true"
    endpoint_public_access = "true"
  }

  depends_on = [
    "aws_iam_role_policy_attachment.cluster-AmazonEKSClusterPolicy",
    "aws_iam_role_policy_attachment.cluster-AmazonEKSServicePolicy",
  ]
}

resource "aws_iam_role" "worker-node-role" {
  name = "${var.project_name}-${var.team_name}-${var.environment}-eks-worker-role"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": ["ec2.amazonaws.com", "eks.amazonaws.com"]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = "${aws_iam_role.worker-node-role.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = "${aws_iam_role.worker-node-role.name}"
}

resource "aws_iam_role_policy_attachment" "node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = "${aws_iam_role.worker-node-role.name}"
}

resource "aws_iam_instance_profile" "worker-node" {
  name = "${var.project_name}-${var.team_name}-${var.environment}-eks-instance-profile"
  role = "${aws_iam_role.worker-node-role.name}"
}

resource "aws_security_group" "worker-node-sg" {
  name        = "${var.project_name}-${var.team_name}-${var.environment}-worker-node-sg"
  description = "Security group for all nodes in the cluster"
  vpc_id      = "${var.vpc_id}"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = "${
    map(
     "Name", "${var.project_name}-${var.team_name}-${var.environment}-worker-node-sg",
    )
  }"
}
resource "aws_security_group_rule" "worker-node-ingress-self" {
  description              = "Allow node to communicate with each other"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = "${aws_security_group.worker-node-sg.id}"
  source_security_group_id = "${aws_security_group.worker-node-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}
resource "aws_security_group_rule" "worker-node-ingress-cluster" {
  description              = "Allow worker Kubelets and pods to receive communication from the cluster control plane"
  from_port                = 1025
  protocol                 = "tcp"
  security_group_id        = "${aws_security_group.worker-node-sg.id}"
  source_security_group_id = "${aws_security_group.eks-sg.id}"
  to_port                  = 65535
  type                     = "ingress"
}
data "aws_ami" "eks-worker-ami" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${aws_eks_cluster.eks-cluster.version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"]
}

locals {
  worker-node-userdata = <<USERDATA
#!/bin/bash -xe
CA_CERTIFICATE_DIRECTORY=/etc/kubernetes/pki
CA_CERTIFICATE_FILE_PATH=$CA_CERTIFICATE_DIRECTORY/ca.crt
mkdir -p $CA_CERTIFICATE_DIRECTORY
echo "${aws_eks_cluster.eks-cluster.certificate_authority.0.data}" | base64 -d >  $CA_CERTIFICATE_FILE_PATH
INTERNAL_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /var/lib/kubelet/kubeconfig
sed -i s,CLUSTER_NAME,${var.project_name}-${var.team_name}-${var.environment}-eks-cluster,g /var/lib/kubelet/kubeconfig
sed -i s,REGION,${data.aws_region.current.name},g /etc/systemd/system/kubelet.service
sed -i s,MAX_PODS,20,g /etc/systemd/system/kubelet.service
sed -i s,MASTER_ENDPOINT,${aws_eks_cluster.eks-cluster.endpoint},g /etc/systemd/system/kubelet.service
sed -i s,INTERNAL_IP,$INTERNAL_IP,g /etc/systemd/system/kubelet.service
DNS_CLUSTER_IP=10.100.0.10
if [[ $INTERNAL_IP == 10.* ]] ; then DNS_CLUSTER_IP=172.20.0.10; fi
sed -i s,DNS_CLUSTER_IP,$DNS_CLUSTER_IP,g /etc/systemd/system/kubelet.service
sed -i s,CERTIFICATE_AUTHORITY_FILE,$CA_CERTIFICATE_FILE_PATH,g /var/lib/kubelet/kubeconfig
sed -i s,CLIENT_CA_FILE,$CA_CERTIFICATE_FILE_PATH,g  /etc/systemd/system/kubelet.service
systemctl daemon-reload
systemctl restart kubelet
USERDATA
}

resource "aws_launch_configuration" "worker-node-lc" {
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.worker-node.name}"
  image_id                    = "${data.aws_ami.eks-worker-ami.id}"
  instance_type               = "${var.instance_type}"
  name_prefix                 = "${var.project_name}-${var.team_name}-${var.environment}-worker-node-"
  security_groups             = ["${aws_security_group.worker-node-sg.id}"]
  user_data_base64            = "${base64encode(local.worker-node-userdata)}"
  key_name             = "javakey"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "worker-node-asg" {
  desired_capacity     = 2
  launch_configuration = "${aws_launch_configuration.worker-node-lc.id}"
  max_size             = 2
  min_size             = 1
  name                 = "${var.project_name}-${var.team_name}-${var.environment}-eks-workers-node"
  vpc_zone_identifier  = ["${var.public_subnet_ids}"]


  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.team_name}-${var.environment}-workers-asg"
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.project_name}-${var.team_name}-${var.environment}-eks-cluster"
    value               = "owned"
    propagate_at_launch = true
  }
}

