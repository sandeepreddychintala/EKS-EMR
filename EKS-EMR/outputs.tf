output "vpc-id" {
    value = "${module.vpc.vpc-id}"
}

output "public_subnet_ids" {
    value = "${module.vpc.public_subnet_ids}"
}

output "private_subnet_ids" {
    value = "${module.vpc.private_subnet_ids}"
}

output "nat_gateway_ip" {
    value = "${module.vpc.nat_gateway_ip}"
}

output "alb_dnsname" {
    value = "${module.ec2.alb_dnsname}"
}