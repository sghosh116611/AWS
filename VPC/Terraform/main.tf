#Creation of VPC
resource "aws_vpc" "myvpc" {
  cidr_block = var.default_cidr_block

  tags = {
    Name = "My-TF-VPC"
  }
}

#Creation of public subnet inside the VPC
resource "aws_subnet" "sub1" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.0.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "sub2" {
  vpc_id = aws_vpc.myvpc.id
  cidr_block = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "us-east-1b"
}

#Creation of internet gateway
resource "aws_internet_gateway" "myigw" {
  vpc_id = aws_vpc.myvpc.id
}

#Creation of route table
resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.myvpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myigw.id
  }
}

#Creation of route table association
resource "aws_route_table_association" "rta1" {
  subnet_id = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "rta2" {
  subnet_id = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

#Creation of security group
resource "aws_security_group" "sg" {
  vpc_id = aws_vpc.myvpc.id

  ingress {
    from_port = 80 //HTTP
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22 //SSH
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "MyTFVPCSG"
  }
}

#Creation of ec2 instances in subnet in vpc
resource "aws_instance" "server1" {
  ami = "ami-07d9b9ddc6cd8dd30"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id = aws_subnet.sub1.id
  user_data = base64encode(file("userData1.sh"))

  tags = {
    Name = "TF-Server1"
  }
}

resource "aws_instance" "server2" {
  ami = "ami-07d9b9ddc6cd8dd30"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id = aws_subnet.sub2.id
  user_data = base64encode(file("userData2.sh"))

  tags = {
    Name = "TF-Server2"
  }
}


#Creation of LB(ALB) in public subnet
resource "aws_lb" "myalb" {
  name               = "myalb"
  internal           = false
  load_balancer_type = "application"

  security_groups = [aws_security_group.sg.id]
  subnets         = [aws_subnet.sub1.id, aws_subnet.sub2.id]

  tags = {
    Name = "TF-ALB"
  }
}

#Creation of Target Group
resource "aws_lb_target_group" "tg" {
  name     = "myTG"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.myvpc.id

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

#Creation of target group attachment
resource "aws_lb_target_group_attachment" "attach1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.server1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "attach2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.server2.id
  port             = 80
}

#Creation of lb listener
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.myalb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.myalb.dns_name
}


