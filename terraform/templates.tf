data "template_file" "webBackendLine" {
  template = "${file("${path.module}/config/web-backend-line.tpl")}"
  count = "${var.webservers_count}"

  vars = {
    hostname = "${element(aws_instance.web.*.tags.Name,count.index)}"
    ip = "${element(aws_instance.web.*.private_ip,count.index)}"
  }
}

data "template_file" "haproxyConf" {
  # module-relative path because of "Embedded Files"
  template = "${file("${path.module}/config/haproxy.cfg.tpl")}"

  vars = {
    web_local_ips = "${join("",data.template_file.webBackendLine.*.rendered)}"
  }
}
