resource "aws_ecr_repository" "main" {
  name                 = "ectr-dev-i231-sample"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# VPC
data "aws_vpc" "vpc" {
  id = "vpc-069f656ea9de1a173"
}

# サブネット
data "aws_subnet" "subnet_a" {
  id = "subnet-0813446eda2ab1d8e"
}

data "aws_subnet" "subnet_b" {
  id = "subnet-0bbf03a5ca6653d46"
}

data "aws_subnet" "subnet_c" {
   id = "subnet-029983d62d52dde8a"
}

resource "aws_internet_gateway" "main" {
  vpc_id = data.aws_vpc.vpc.id
  tags = {
    name = "sample-internet-gateway"
  }
}

# ルートテーブル
data "aws_route_table" "main" {
  route_table_id  =  "rtb-0ad75363c371989ca"
}

# ルート
resource "aws_route" "main" {
  destination_cidr_block = "0.0.0.0/0"
  route_table_id         = data.aws_route_table.main.id
  gateway_id             = aws_internet_gateway.main.id

}

resource "aws_route_table_association" "public_1a" {
  subnet_id      = data.aws_subnet.subnet_a.id
  route_table_id = data.aws_route_table.main.id
}

resource "aws_route_table_association" "public_1c" {
  subnet_id      = data.aws_subnet.subnet_b.id
  route_table_id = data.aws_route_table.main.id
}

resource "aws_route_table_association" "public_1d" {
  subnet_id      = data.aws_subnet.subnet_c.id
  route_table_id = data.aws_route_table.main.id
}

resource "aws_security_group" "alb" {
  name = "alb-security-group"
  description = "alb-security-group"
  vpc_id = data.aws_vpc.vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    name = "alb-security-group"
  }
}

resource "aws_security_group_rule" "alb" {
  security_group_id = aws_security_group.alb.id
  type = "ingress"
  from_port = 80
  to_port = 80
  protocol = "tcp"

  cidr_blocks = ["0.0.0.0/0"]  
}

resource "aws_lb" "main" {

  load_balancer_type = "application"
  name = "alb-dev-I231-sample"

  security_groups = [ aws_security_group.alb.id ]
  subnets = [ data.aws_subnet.subnet_a.id,data.aws_subnet.subnet_b.id,data.aws_subnet.subnet_c.id ]
  
}

resource "aws_lb_listener" "main"{
  port = "80"
  protocol = "HTTP"

  load_balancer_arn = aws_lb.main.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      status_code = "200"
      message_body = "ok"
    }
  }
}

//cluster
resource "aws_ecs_cluster" "main"{
  name = "ecls-dev-I231-sample"
}

resource "aws_lb_target_group" "main"{
  name = "tg-dev-I231-sample-app"

  vpc_id = data.aws_vpc.vpc.id

  port = 80
  protocol = "HTTP"
  target_type = "ip"

  health_check {
    port = 80
    path = "/"
  }
}

resource "aws_lb_listener_rule" "main" {

  listener_arn = aws_lb_listener.main.arn

  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  condition {
    path_pattern{
      values = ["*"]    
    }
  }
}

resource "aws_security_group" "ecs" {
  name = "security-group"
  description = "handson ecs"

  vpc_id = data.aws_vpc.vpc.id

   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security-group"
  }
}

resource "aws_security_group_rule" "ecs" {
  security_group_id = aws_security_group.ecs.id

  # インターネットからセキュリティグループ内のリソースへのアクセス許可設定
  type = "ingress"

  # TCPでの80ポートへのアクセスを許可する
  from_port = 80
  to_port   = 80
  protocol  = "tcp"

  # 同一VPC内からのアクセスのみ許可
  cidr_blocks = ["10.0.0.0/16"]
}