output "security_group" {
  value = "${aws_security_group.consul.id}"
}

output "launch_configuration" {
  value = "${aws_launch_configuration.consul_lc.id}"
}

output "asg_name" {
  value = "${aws_autoscaling_group.consul_asg.id}"
}

output "asg_arn" {
  value = "${aws_autoscaling_group.consul_asg.arn}"
}

output "elb_name" {
  value = "${aws_elb.consul_elb_internal.name}"
}

output "elb_dns" {
  value = "${aws_elb.consul_elb_internal.dns_name}"
}

output "zone_id" {
  value = "${aws_elb.consul_elb_internal.zone_id}"
}
