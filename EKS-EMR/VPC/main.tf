resource "aws_vpc" "main" {
  cidr_block = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "gateway" {
    vpc_id = "${aws_vpc.main.id}"
    tags {
        Name = "${var.project_name}-${var.team_name}-${var.environment}-igw"
    }
}

resource "aws_subnet" "public" {
  count = "${length(var.azs)}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${element(var.azs, count.index)}"
  cidr_block = "${element(var.public_subnet_cidrs, count.index)}"
  map_public_ip_on_launch = true
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-public-subnet-${element(var.azs, count.index)}"
  }
}


resource "aws_subnet" "private" {
  count = "${length(var.azs)}"
  vpc_id = "${aws_vpc.main.id}"
  availability_zone = "${element(var.azs, count.index)}"
  map_public_ip_on_launch = false
  cidr_block = "${element(var.private_subnet_cidrs, count.index)}"
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}--private-subnet-${element(var.azs, count.index)}"
  }
}




resource "aws_eip" "nat" {
  vpc      = true
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-natgw-ip"
  }
}

resource "aws_nat_gateway" "nat" {
  allocation_id = "${aws_eip.nat.id}"
  subnet_id     = "${element(aws_subnet.public.*.id, 0)}"
}

resource "aws_route_table" "rtb-public" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.gateway.id}"
  }
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-public-route"
  }
}


resource "aws_route_table" "rtb-private" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.nat.id}"
  }
  tags {
    Name = "${var.project_name}-${var.team_name}-${var.environment}-private-route"
  }
}

resource "aws_route_table_association" "asso-public" {
  count = "${length(var.azs)}"
  subnet_id = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtb-public.id}"
}

resource "aws_route_table_association" "asso-private" {
  count = "${length(var.azs)}"
  subnet_id = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${aws_route_table.rtb-private.id}"
}