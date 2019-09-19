provider "aws" {
  version = "1.13.0"
  region = "${var.aws_region}"
  profile = "${var.profile}"
  
}

#-------------Creating Iam role and Instance Profile--------------
resource "aws_iam_instance_profile" "s3_access_profile" {
  name = "s3_access"
  role = "${aws_iam_role.s3_access_role.name}"
}

resource "aws_iam_role_policy" "s3_access_policy" {
  name = "s3_access_policy"
  role = "${aws_iam_role.s3_access_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": "s3:*",
    "Resource": "*"
  }]
}
EOF
}

resource "aws_iam_role" "s3_access_role" {
  name = "s3_access_role" 

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
  {
    "Action": "sts:AssumeRole",
    "Principal": {
        "Service": "ec2.amazonaws.com"
  },
    "Effect": "Allow",
    "Sid": ""
    }
  ]
}
EOF
}

#---------Creating VPC-----------
resource "aws_vpc" "tw_vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags {
    Name = "tw_vpc"
  }
}

resource "aws_internet_gateway" "tw_internet_gateway" {
  vpc_id = "${aws_vpc.tw_vpc.id}"

  tags {
    Name = "tw_igw"
  }
}

resource "aws_route_table" "tw_public_rt" {
  vpc_id = "${aws_vpc.tw_vpc.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.tw_internet_gateway.id}"
  }
}

resource "aws_default_route_table" "tw_private_rt" {
  default_route_table_id = "${aws_vpc.tw_vpc.default_route_table_id}"
}

resource "aws_subnet" "tw_public1_subnet" {
  vpc_id                  = "${aws_vpc.tw_vpc.id}"
  cidr_block              = "${var.cidrs["public1"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "tw_public1"
  }
}

resource "aws_subnet" "tw_public2_subnet" {
  vpc_id                  = "${aws_vpc.tw_vpc.id}"
  cidr_block              = "${var.cidrs["public2"]}"
  map_public_ip_on_launch = true
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "tw_public2"
  }
}


resource "aws_subnet" "tw_private1_subnet" {
  vpc_id                  = "${aws_vpc.tw_vpc.id}"
  cidr_block              = "${var.cidrs["private1"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[0]}"

  tags {
    Name = "tw_private1"
  }
}

resource "aws_subnet" "tw_private2_subnet" {
  vpc_id                  = "${aws_vpc.tw_vpc.id}"
  cidr_block              = "${var.cidrs["private2"]}"
  map_public_ip_on_launch = false
  availability_zone       = "${data.aws_availability_zones.available.names[1]}"

  tags {
    Name = "tw_private2"
  }
}

resource "aws_route_table_association" "tw_public1_assoc" {
  subnet_id      = "${aws_subnet.tw_public1_subnet.id}"
  route_table_id = "${aws_route_table.tw_public_rt.id}"
}

resource "aws_route_table_association" "tw_public2_assoc" {
  subnet_id      = "${aws_subnet.tw_public2_subnet.id}"
  route_table_id = "${aws_route_table.tw_public_rt.id}"
}


resource "aws_route_table_association" "tw_private1_assoc" {
  subnet_id      = "${aws_subnet.tw_private1_subnet.id}"
  route_table_id = "${aws_default_route_table.tw_private_rt.id}"
}

resource "aws_route_table_association" "tw_private2_assoc" {
  subnet_id      = "${aws_subnet.tw_private2_subnet.id}"
  route_table_id = "${aws_default_route_table.tw_private_rt.id}"
}


#----------------Creating Launch Config---------------

resource "aws_launch_configuration" "tw_lc1" {
  name_prefix          = "wp-lc1-"
  image_id             = "${aws_ami_from_instance.tw_golden1.id}"
  instance_type        = "${var.lc_instance_type}"
  security_groups      = ["${aws_security_group.tw_private_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.s3_access_profile.id}"
  key_name             = "${aws_key_pair.tw_auth.id}"
  user_data            = "${file("userdata")}" 
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_launch_configuration" "tw_lc2" {
  name_prefix          = "wp-lc2-"
  image_id             = "${aws_ami_from_instance.tw_golden2.id}"
  instance_type        = "${var.lc_instance_type}"
  security_groups      = ["${aws_security_group.tw_private_sg.id}"]
  iam_instance_profile = "${aws_iam_instance_profile.s3_access_profile.id}"
  key_name             = "${aws_key_pair.tw_auth.id}"
  #user_data            = "${file("userdata")}" 
  lifecycle {
    create_before_destroy = true
  }
}

#----------_AutoScalingGroup---------------

resource "aws_autoscaling_group" "tw_asg1" {
  name                      = "asg-${aws_launch_configuration.tw_lc1.id}"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_hct}"
  desired_capacity          = "${var.asg_cap}"
  force_delete              = true
  load_balancers             = ["${aws_elb.tw_elb1.id}"]
  vpc_zone_identifier       = ["${aws_subnet.tw_private1_subnet.id}"]
  launch_configuration      = "${aws_launch_configuration.tw_lc1.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "tw_asg2" {
  name                      = "asg-${aws_launch_configuration.tw_lc2.id}"
  max_size                  = "${var.asg_max}"
  min_size                  = "${var.asg_min}"
  health_check_grace_period = "${var.asg_grace}"
  health_check_type         = "${var.asg_hct}"
  desired_capacity          = "${var.asg_cap}"
  force_delete              = true
  load_balancers             = ["${aws_elb.tw_elb2.id}"]
  vpc_zone_identifier       = ["${aws_subnet.tw_private1_subnet.id}", "${aws_subnet.tw_private2_subnet.id}"]
  launch_configuration      = "${aws_launch_configuration.tw_lc2.name}"

  lifecycle {
    create_before_destroy = true
  }
}

#--------Creating Security Groups-------------
resource "aws_security_group" "tw_dev_sg" {
  name   = "tw_dev_sg"
  vpc_id = "${aws_vpc.tw_vpc.id}"

  ingress {
    from_port  = 22
    to_port    = 22
    protocol   = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  ingress {
    from_port  = 80
    to_port    = 80
    protocol   = "tcp"
    cidr_blocks = ["${var.localip}"]
  }

  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tw_public_sg" {
  name   = "tw_public_sg"
  vpc_id = "${aws_vpc.tw_vpc.id}"

  ingress {
    from_port  = 80
    to_port    = 80
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port  = 443
    to_port    = 443
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "tw_private_sg" {
  name   = "tw_private_sg"
  vpc_id = "${aws_vpc.tw_vpc.id}"

  ingress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["${var.vpc_cidr}"]
  }

  egress {
    from_port  = 0
    to_port    = 0
    protocol   = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#--------S3 Vpc endpoint------------
resource "aws_vpc_endpoint" "tw_private-s3_endpoint" {
  vpc_id          = "${aws_vpc.tw_vpc.id}"
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = ["${aws_vpc.tw_vpc.main_route_table_id}", "${aws_route_table.tw_public_rt.id}"]
}

#------Adding S3 Bucket--------
resource "random_id" "tw_web_bucket" {
  byte_length = 2
}

resource "random_id" "tw_app_bucket" {
  byte_length = 2
}

resource "aws_s3_bucket" "web" {
  bucket        = "${var.domain_name}-${random_id.tw_web_bucket.dec}"
  acl           = "private"
  force_destroy = true

  tags {
    Name = "web bucket"
  }
}
resource "aws_s3_bucket_object" "static" {
  bucket = "${aws_s3_bucket.web.bucket}"
  key = "static"
  source = "static/*"
}
resource "aws_s3_bucket" "app" {
  bucket        = "${var.domain_name}-${random_id.tw_app_bucket.dec}"
  acl           = "private"
  force_destroy = true

  tags {
    Name = "app bucket"
  }
}


#-----Creating Key Pair--------

resource "aws_key_pair" "tw_auth" {
  key_name   = "${var.key_name}"
  public_key = "${file(var.public_key_path)}"
}

#------Web server ami-------
resource "aws_instance" "tw_web" {
  instance_type = "${var.dev_instance_type}"
  ami           = "${var.dev_ami}"

  tags {
    Name = "tw_web"
  }

  key_name               = "${aws_key_pair.tw_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.tw_dev_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.s3_access_profile.id}"
  subnet_id              = "${aws_subnet.tw_public1_subnet.id}"

}

#--------App Server AMI-------
resource "aws_instance" "tw_app" {
  instance_type = "${var.dev_instance_type}"
  ami           = "${var.dev_ami}"

  tags {
    Name = "tw_app"
  }

  key_name               = "${aws_key_pair.tw_auth.id}"
  vpc_security_group_ids = ["${aws_security_group.tw_dev_sg.id}"]
  iam_instance_profile   = "${aws_iam_instance_profile.s3_access_profile.id}"
  subnet_id              = "${aws_subnet.tw_public1_subnet.id}"

  provisioner "local-exec" {
    command = <<EOD
  cat <<EOF >aws_hosts
  [app]
  ${aws_instance.tw_app.public_ip}

EOF
EOD
  }
  provisioner "local-exec" {
    command = "aws ec2 wait instance-status-ok --instance-ids ${aws_instance.tw_app.id} --profile ${var.profile} && /usr/local/bin/ansible-playbook -i aws_hosts configure.yml"
  }
}

#--------Creating Load Balancer------------

resource "aws_elb" "tw_elb1" {
  name = "${var.domain_name}-elb1"
  subnets = ["${aws_subnet.tw_public1_subnet.id}", "${aws_subnet.tw_public2_subnet.id}"]
  security_groups = ["${aws_security_group.tw_public_sg.id}"]
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
    }
  health_check {
    healthy_threshold = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout = "${var.elb_timeout}"
    interval = "${var.elb_interval}"
    target = "TCP:80"
    }
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400
  tags {
    Name = "${var.domain_name}-elb1"
  }
}

resource "aws_elb" "tw_elb2" {
  name = "${var.domain_name}-elb2"
  subnets = ["${aws_subnet.tw_public1_subnet.id}", "${aws_subnet.tw_public2_subnet.id}"]
  security_groups = ["${aws_security_group.tw_public_sg.id}"]
  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
    }
  health_check {
    healthy_threshold = "${var.elb_healthy_threshold}"
    unhealthy_threshold = "${var.elb_unhealthy_threshold}"
    timeout = "${var.elb_timeout}"
    interval = "${var.elb_interval}"
    target = "TCP:80"
    }
  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400
  tags {
    Name = "${var.domain_name}-elb2"
  }
}

#------Creating web ami------------
resource "aws_ami_from_instance" "tw_golden1" {
  name = "tw_ami-${var.time}"
  source_instance_id = "${aws_instance.tw_web.id}"
  provisioner "local-exec" {
    command = <<EOT
    cat <<EOF >userdata
    #!/bin/bash
    sudo yum install httpd -y
    /usr/bin/aws s3 sync s3://${aws_s3_bucket.web.bucket} /var/www/html/
    /bin/touch /var/spool/cron/root
    sudo /bin/echo '*/5 * * * * aws s3 sync s3://${aws_s3_bucket.web.bucket} /var/www/html/' >> /var/spool/cron/root
    sudo service httpd start
  EOF
  EOT
  }
}
#--------Creating App Ami----------------
resource "aws_ami_from_instance" "tw_golden2" {
  name = "tw_ami-${var.time}"
  source_instance_id = "${aws_instance.tw_app.id}"
  }
