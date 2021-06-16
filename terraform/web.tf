variable "webservers_count" {
  default = 2
}

variable "web_ips" {
  default = [
    "10.0.1.11",
    "10.0.1.12",
    "10.0.1.13",
    "10.0.1.14",
    "10.0.1.15"
  ]
}
resource "aws_instance" "web" {
  count = "${var.webservers_count}"
  ami           = "ami-0567f647e75c7bc05"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.TfDemo1Subnet.id}"
  private_ip = "${element(var.web_ips,count.index)}"
  user_data = "${file("config/webUserdata.sh")}"
  associate_public_ip_address = true
  key_name = "${var.aws_key_name}"
  # Must use vpc_security_group_ids because not default VPC
  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.sshMgmt.id}",
    "${aws_security_group.allowPing.id}"
  ]
  tags = {
    Name = "Web${count.index + 1}"
  }

  # Allow provisioner to login using ssh key
  connection {
    type = "ssh"
    user = "ubuntu"
    private_key = "${file(var.private_key)}"
    timeout = "5m"
  }
}
