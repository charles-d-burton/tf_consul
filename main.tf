#Create a bucket to backup consul key/value stores
resource "aws_s3_bucket" "tf-consul-backups" {
  bucket = "tf-consul-backups-${var.env}-${var.region}"
  acl    = "private"

  lifecycle_rule {
    id      = "backups"
    prefix  = "backups/"
    enabled = true

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "GLACIER"
    }

    expiration {
      days = 90
    }
  }

  lifecycle {
    prevent_destroy = true
  }

  tags {
    Name        = "Consul Backups ${var.region}"
    Environment = "${var.env}"
  }
}

#Give consul the ec2 assume role privileges
resource "aws_iam_role" "consul" {
  name               = "consul-${var.region}"
  assume_role_policy = "${data.aws_iam_policy_document.consul_assume_role_policy.json}"
}

#Give consul access to the S3 bucket for backups as well as ec2 for reading tags
resource "aws_iam_policy" "consul" {
  name = "consul-policy-${var.region}"

  policy = "${data.aws_iam_policy_document.consul_instance_policy.json}"
}

resource "aws_iam_policy_attachment" "consul" {
  name       = "consul-attachment-${var.region}"
  policy_arn = "${aws_iam_policy.consul.arn}"
  roles      = ["${aws_iam_role.consul.name}"]
}

resource "aws_iam_instance_profile" "consul_instance_profile" {
  name = "consul-instance-profile-${var.region}"
  role = "${aws_iam_role.consul.name}"
}

#Generate a radom base64 encoded id for the gossip protocol encryption
resource "random_id" "key" {
  byte_length = 16
}

#Generate the launch config data based on a template, creates and coalesces the cluster
data "template_file" "consul_setup" {
  template = "${file("${path.module}/consul_setup.sh")}"

  vars {
    region         = "${var.region}"
    bucket         = "${aws_s3_bucket.tf-consul-backups.id}"
    encryption_key = "${random_id.key.b64_std}"
    num_servers    = "${var.min_cluster_size}"
  }
}

#Create the TCP load balancer for the cluster
resource "aws_elb" "consul_elb_internal" {
  name = "consul-elb-internal-${var.region}"

  internal = "true"

  #The same availability zones as our instances
  subnets = ["${var.private_subnets}"]

  security_groups = ["${aws_security_group.consul_elb_internal.id}"]

  listener {
    instance_port     = 8500
    instance_protocol = "tcp"
    lb_port           = 8500
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 8301
    instance_protocol = "tcp"
    lb_port           = 8301
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 10
    unhealthy_threshold = 2
    timeout             = 5
    target              = "TCP:8500"
    interval            = 30
  }
}

#Create the autoscaling group to grow and shrink the cluster
resource "aws_autoscaling_group" "consul_asg" {
  vpc_zone_identifier  = ["${var.private_subnets}"]
  name                 = "consul-asg-${var.region}"
  max_size             = "${var.max_cluster_size}"
  min_size             = "${var.min_cluster_size}"
  desired_capacity     = "${var.min_cluster_size}"
  force_delete         = true
  launch_configuration = "${aws_launch_configuration.consul_lc.name}"
  load_balancers       = ["${aws_elb.consul_elb_internal.name}"]

  tag {
    key                 = "Name"
    value               = "${var.tagName}-${count.index}"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "ConsulRole"
    value               = "Server"
    propagate_at_launch = "true"
  }

  tag {
    key                 = "consul-cluster"
    value               = "${var.region}"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

#Generate notifications for scaling events
resource "aws_autoscaling_notification" "consul_notifications" {
  group_names = [
    "${aws_autoscaling_group.consul_asg.name}",
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
  ]

  topic_arn = "${var.notification_arn}"
}

#Create the launch config for the instances to use in the ASG
resource "aws_launch_configuration" "consul_lc" {
  name_prefix          = "consul-lc-"
  iam_instance_profile = "${aws_iam_instance_profile.consul_instance_profile.id}"
  image_id             = "${lookup(var.ami, var.region)}"
  instance_type        = "${var.instance_type}"
  security_groups      = ["${aws_security_group.consul.id}"]
  user_data            = "${data.template_file.consul_setup.rendered}"
  key_name             = "${var.key_name}"

  lifecycle {
    create_before_destroy = true
  }
}

#Security groups allowing default consul ports in the local network for the load balancer
resource "aws_security_group" "consul_elb_internal" {
  name        = "consul_elb"
  description = "Security group for console ELB accesss"
  vpc_id      = "${var.vpc_id}"

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # This is for outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#Security Groups for the instances
resource "aws_security_group" "consul" {
  name        = "consul_${var.region}"
  description = "Consul internal traffic + maintenance."
  vpc_id      = "${var.vpc_id}"

  # RPC Client Traffic
  ingress {
    from_port   = 8300
    to_port     = 8300
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  # Serf Protocol LAN - TCP
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  ingress {
    from_port       = 8301
    to_port         = 8301
    protocol        = "tcp"
    security_groups = ["${aws_elb.consul_elb_internal.source_security_group_id}"]
  }

  #Serf Protocol LAN - UDP
  ingress {
    from_port   = 8301
    to_port     = 8301
    protocol    = "udp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  # Serf Protocol WAN - TCP
  ingress {
    from_port   = 8302
    to_port     = 8302
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #Serf Protocol WAN - UDP
  ingress {
    from_port   = 8302
    to_port     = 8302
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #CLI - RPC
  ingress {
    from_port   = 8400
    to_port     = 8400
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  #HTTP REST Interface
  ingress {
    from_port       = 8500
    to_port         = 8500
    protocol        = "tcp"
    security_groups = ["${aws_elb.consul_elb_internal.source_security_group_id}"]
  }

  ingress {
    from_port   = 8500
    to_port     = 8500
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  #DNS Interface
  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  ingress {
    from_port   = 8600
    to_port     = 8600
    protocol    = "udp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  # These are for maintenance
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.aws_vpc.selected.cidr_block}"]
  }

  # This is for outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
