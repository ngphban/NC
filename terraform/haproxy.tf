resource "aws_instance" "haproxy" {
  ami           = "ami-0567f647e75c7bc05"
  instance_type = "t2.micro"
  subnet_id = "${aws_subnet.TfDemo1Subnet.id}"
  private_ip = "10.0.1.10"

  associate_public_ip_address = true
  key_name = "${var.aws_key_name}"
  # Must use vpc_security_group_ids because not default VPC
  vpc_security_group_ids = [
    "${aws_security_group.web.id}",
    "${aws_security_group.sshMgmt.id}",
    "${aws_security_group.allowPing.id}"
  ]
  tags = {
    Name = "HA Proxy"
  }

  # Allow provisioner to login using ssh key
  connection {
    type = "ssh"
    host = self.public_ip
    user = "ubuntu"
    private_key = "${file(var.private_key)}"
    timeout = "10m"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 5",
      "sudo add-apt-repository -y ppa:vbernat/haproxy-1.8",
      "sudo apt-get -y update",
      "sudo apt-get -y install haproxy"
    ]
  }

  provisioner "file" {
    content = "${data.template_file.haproxyConf.rendered}"
    # Cant copy to /etc because of permissions, so mv later with sudo
    destination = "/tmp/haproxy.cfg"
    # destination = "/etc/haproxy/haproxy.cfg"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mv /tmp/haproxy.cfg /etc/haproxy/haproxy.cfg",
      "sudo service haproxy restart"
    ]
  }

}

output "HAProxy_ip" {
  value = "${aws_instance.haproxy.public_ip}"
}
