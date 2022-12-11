resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
}

resource "aws_internet_gateway" "igw" {
   vpc_id =  aws_vpc.vpc.id
}

resource "aws_subnet" "publicsubnets" {
  vpc_id =  aws_vpc.vpc.id
  cidr_block = "10.0.0.0/20"
  map_public_ip_on_launch = true
}

resource "aws_route_table" "publicroute" {
   vpc_id =  aws_vpc.vpc.id
   route {
       cidr_block = "0.0.0.0/0"
       gateway_id = aws_internet_gateway.igw.id
    }
}

resource "aws_route_table_association" "publicrouteassociation" {
   subnet_id = aws_subnet.publicsubnets.id
   route_table_id = aws_route_table.publicroute.id
}

resource "tls_private_key" "key_pair" {
   algorithm = "RSA"
   rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "amazon_linux_key_pair"
  public_key = tls_private_key.key_pair.public_key_openssh
}

resource "aws_security_group" "allow_22" {
  name        = "allow_22"
  description = "Allow port 22"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "Port 22"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_80" {
  name        = "allow_80"
  description = "Allow port 80"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "Port 80"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "allow_8080" {
  name        = "allow_8080"
  description = "Allow port 8080"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    description      = "Port 8080"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    security_groups  = [aws_security_group.allow_80.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "elb" {
  name            = "elb"
  security_groups = [aws_security_group.allow_80.id]
  subnets         = [aws_subnet.publicsubnets.id]

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
    target              = "TCP:8080"
  }

  listener {
    lb_port           = 80
    lb_protocol       = "http"
    instance_port     = "8080"
    instance_protocol = "http"
  }
}

resource "aws_launch_configuration" "launch_conf" {
  name_prefix     = "amazon_linux_"
  image_id        = "ami-0b0dcb5067f052a63"
  instance_type   = "t2.micro"
  key_name        = aws_key_pair.ec2_key_pair.id
  security_groups = [aws_security_group.allow_8080.id, aws_security_group.allow_22.id]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "auto_scale_group" {
  name                 = "amazon_linux_auto_scale_group"
  launch_configuration = aws_launch_configuration.launch_conf.name
  min_size             = 1
  max_size             = 1
  vpc_zone_identifier  = [aws_subnet.publicsubnets.id]
  load_balancers       = [aws_elb.elb.id]
  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "reboot_policy_doc" {
  statement {
    effect = "Allow"
    actions = ["ec2:RebootInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "aws:ResourceTag/aws:autoscaling:groupName"
      values = ["amazon_linux_auto_scale_group"]
    }
  }

  statement {
    effect = "Allow"
    actions = ["iam:ChangePassword"]
    resources = ["arn:aws:iam::554327718445:user/${aws_iam_user.reboot_user.name}"]
  }

  statement {
    effect = "Allow"
    actions = ["ec2:DescribeInstances"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "reboot_policy" {
  name   = "reboot_policy"
  path   = "/"
  policy = data.aws_iam_policy_document.reboot_policy_doc.json
}

resource "aws_iam_user" "reboot_user" {
  name = "reboot_user"
}

resource "aws_iam_user_policy_attachment" "attach_policy" {
  user       = aws_iam_user.reboot_user.name
  policy_arn = aws_iam_policy.reboot_policy.arn
}

resource "aws_iam_user_login_profile" "login_profile" {
  user                    = aws_iam_user.reboot_user.name
  password_reset_required = true
}

output "password" {
  value     = aws_iam_user_login_profile.login_profile.password
  sensitive = false
}

data "aws_instances" "instances" {
  instance_tags = {
    "aws:autoscaling:groupName" = aws_autoscaling_group.auto_scale_group.name
  }
  instance_state_names = ["running"]
}