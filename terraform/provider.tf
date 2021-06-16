provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "ap-southeast-2"
}

resource "aws_vpc" "TfDemo1Vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "TfDemo1 VPC"
  }
}

resource "aws_subnet" "TfDemo1Subnet" {
  vpc_id = "${aws_vpc.TfDemo1Vpc.id}"
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "TfDemo1 Subnet"
  }
}

resource "aws_internet_gateway" "TfDemo1Internet" {
    vpc_id = "${aws_vpc.TfDemo1Vpc.id}"
}

resource "aws_route_table" "route_table" {
  vpc_id = "${aws_vpc.TfDemo1Vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.TfDemo1Internet.id}"
  }

  tags = {
    Name = "Main Route Table"
  }
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = "${aws_subnet.TfDemo1Subnet.id}"
  route_table_id = "${aws_route_table.route_table.id}"
}

resource "aws_security_group" "sshMgmt" {
  name = "ssh_managment"
  description = "Allow admins to manage the servers using SSH from any IP"
  vpc_id = "${aws_vpc.TfDemo1Vpc.id}"

  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ssh Input"
  }

  egress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ssh Output"
  }

  tags = {
    Name = "SSH Managment"
  }
}

resource "aws_security_group" "allowPing" {
  name = "allow_ping"
  description = "Allow to get and return pings"
  vpc_id = "${aws_vpc.TfDemo1Vpc.id}"

  ingress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Ping Input (echo request)"
  }

  egress {
    from_port = -1
    to_port = -1
    protocol = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ping Output (echo reply)"
  }

  tags = {
    Name = "Allow Ping"
  }
}

resource "aws_security_group" "web" {
  name = "web_ports"
  description = "Allow webservers to get http&https requests"
  vpc_id = "${aws_vpc.TfDemo1Vpc.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Http Input"
  }
  egress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Http Output"
  }

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Https Input"
  }

  egress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow Https Output"
  }

  tags = {
    Name = "Web ports"
  }
}
