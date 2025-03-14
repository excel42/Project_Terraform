
# VPC 설정
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "main-vpc"
  }
}

# 퍼블릭 서브넷 (웹 서버 및 ALB용)
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-northeast-2a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-1"
  }
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-northeast-2c"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "public-subnet-2"
  }
}

# 프라이빗 서브넷 (WAS 서버용)
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "ap-northeast-2a"
  
  tags = {
    Name = "private-subnet-1"
  }
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = "ap-northeast-2c"
  
  tags = {
    Name = "private-subnet-2"
  }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "main-igw"
  }
}

# 라우팅 테이블 - 퍼블릭
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  
  tags = {
    Name = "public-rt"
  }
}

# 라우팅 테이블 - 프라이빗
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name = "private-rt"
  }
}

# 서브넷 연결 - 퍼블릭
resource "aws_route_table_association" "public_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public.id
}

# 서브넷 연결 - 프라이빗
resource "aws_route_table_association" "private_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private.id
}

# 보안 그룹 - ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "alb-sg"
  }
}

# 보안 그룹 - 웹 서버
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실제 환경에서는 특정 IP로 제한하는 것이 좋습니다
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "web-sg"
  }
}

# 보안 그룹 - WAS 서버
resource "aws_security_group" "was_sg" {
  name        = "was-sg"
  description = "Security group for WAS servers"
  vpc_id      = aws_vpc.main.id
  
  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # 실제 환경에서는 특정 IP로 제한하는 것이 좋습니다
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    Name = "was-sg"
  }
}

# ALB 생성
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  
  enable_deletion_protection = false
  
  tags = {
    Name = "main-alb"
  }
}

# ALB 타겟 그룹 - 웹 서버
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
  
  health_check {
    path                = "/"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

# ALB 리스너
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# 타겟 그룹 연결 - 웹 서버
resource "aws_lb_target_group_attachment" "web_1" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "web_2" {
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web_2.id
  port             = 80
}

# EC2 키 페어 (이미 생성된 키 페어 사용)
# resource "aws_key_pair" "deployer" {
#   key_name   = "deployer-key"
#   public_key = "실제 퍼블릭 키 값을 입력하세요"
# }

# EC2 인스턴스 - 웹 서버 1 (Nginx)
resource "aws_instance" "web_1" {
  ami                    = "ami-0f3a440bbcff3d043" # Amazon Linux 2023 (ap-northeast-2)
  instance_type          = "t2.micro" # 가장 저렴한 인스턴스 타입
  subnet_id              = aws_subnet.public_1.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  # key_name               = aws_key_pair.deployer.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              # Amazon Linux 2023 패키지 업데이트
              dnf update -y
              
              # Nginx 설치
              dnf install -y nginx
              
              # Nginx 설정
              cat > /etc/nginx/conf.d/was-proxy.conf << 'CONFEND'
              upstream was_servers {
                  server ${aws_instance.was_1.private_ip}:8080;
                  server ${aws_instance.was_2.private_ip}:8080;
              }
              
              server {
                  listen 80;
                  
                  location / {
                      proxy_pass http://was_servers;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }
                  
                  # 간단한 상태 페이지
                  location /status {
                      return 200 'Web Server 1 is running!';
                      add_header Content-Type text/plain;
                  }
              }
              CONFEND
              
              # 기본 페이지 생성
              mkdir -p /usr/share/nginx/html
              echo "<h1>This is Nginx Web Server 1</h1>" > /usr/share/nginx/html/index.html
              
              # Nginx 서비스 시작 및 활성화
              systemctl start nginx
              systemctl enable nginx
              EOF
  
  tags = {
    Name = "web-server-1-nginx"
  }
}

# EC2 인스턴스 - 웹 서버 2 (Nginx)
resource "aws_instance" "web_2" {
  ami                    = "ami-0f3a440bbcff3d043" # Amazon Linux 2023 (ap-northeast-2)
  instance_type          = "t2.micro" # 가장 저렴한 인스턴스 타입
  subnet_id              = aws_subnet.public_2.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  # key_name               = aws_key_pair.deployer.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              # Amazon Linux 2023 패키지 업데이트
              dnf update -y
              
              # Nginx 설치
              dnf install -y nginx
              
              # Nginx 설정
              cat > /etc/nginx/conf.d/was-proxy.conf << 'CONFEND'
              upstream was_servers {
                  server ${aws_instance.was_1.private_ip}:8080;
                  server ${aws_instance.was_2.private_ip}:8080;
              }
              
              server {
                  listen 80;
                  
                  location / {
                      proxy_pass http://was_servers;
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;
                  }
                  
                  # 간단한 상태 페이지
                  location /status {
                      return 200 'Web Server 2 is running!';
                      add_header Content-Type text/plain;
                  }
              }
              CONFEND
              
              # 기본 페이지 생성
              mkdir -p /usr/share/nginx/html
              echo "<h1>This is Nginx Web Server 2</h1>" > /usr/share/nginx/html/index.html
              
              # Nginx 서비스 시작 및 활성화
              systemctl start nginx
              systemctl enable nginx
              EOF
  
  tags = {
    Name = "web-server-2-nginx"
  }
}

# EC2 인스턴스 - WAS 서버 1
resource "aws_instance" "was_1" {
  ami                    = "ami-0f3a440bbcff3d043" # Amazon Linux 2023 (ap-northeast-2)
  instance_type          = "t2.micro" # 가장 저렴한 인스턴스 타입
  subnet_id              = aws_subnet.private_1.id
  vpc_security_group_ids = [aws_security_group.was_sg.id]
  # key_name               = aws_key_pair.deployer.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y java-17-amazon-corretto
              
              # Tomcat 설치
              cd /opt
              wget https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.18/bin/apache-tomcat-10.1.18.tar.gz
              tar -xzvf apache-tomcat-10.1.18.tar.gz
              mv apache-tomcat-10.1.18 tomcat
              
              # 테스트 페이지 생성
              mkdir -p /opt/tomcat/webapps/ROOT
              echo "<h1>This is WAS Server 1</h1>" > /opt/tomcat/webapps/ROOT/index.jsp
              
              # Tomcat 시작
              /opt/tomcat/bin/startup.sh
              
              # 부팅 시 Tomcat 자동 시작
              cat > /etc/systemd/system/tomcat.service << 'SERVICEEND'
              [Unit]
              Description=Apache Tomcat Web Application Container
              After=network.target
              
              [Service]
              Type=forking
              ExecStart=/opt/tomcat/bin/startup.sh
              ExecStop=/opt/tomcat/bin/shutdown.sh
              User=root
              Group=root
              
              [Install]
              WantedBy=multi-user.target
              SERVICEEND
              
              systemctl daemon-reload
              systemctl enable tomcat
              EOF
  
  tags = {
    Name = "was-server-1"
  }
}

# EC2 인스턴스 - WAS 서버 2
resource "aws_instance" "was_2" {
  ami                    = "ami-0f3a440bbcff3d043" # Amazon Linux 2023 (ap-northeast-2)
  instance_type          = "t2.micro" # 가장 저렴한 인스턴스 타입
  subnet_id              = aws_subnet.private_2.id
  vpc_security_group_ids = [aws_security_group.was_sg.id]
  # key_name               = aws_key_pair.deployer.key_name
  
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y java-17-amazon-corretto
              
              # Tomcat 설치
              cd /opt
              wget https://dlcdn.apache.org/tomcat/tomcat-10/v10.1.18/bin/apache-tomcat-10.1.18.tar.gz
              tar -xzvf apache-tomcat-10.1.18.tar.gz
              mv apache-tomcat-10.1.18 tomcat
              
              # 테스트 페이지 생성
              mkdir -p /opt/tomcat/webapps/ROOT
              echo "<h1>This is WAS Server 2</h1>" > /opt/tomcat/webapps/ROOT/index.jsp
              
              # Tomcat 시작
              /opt/tomcat/bin/startup.sh
              
              # 부팅 시 Tomcat 자동 시작
              cat > /etc/systemd/system/tomcat.service << 'SERVICEEND'
              [Unit]
              Description=Apache Tomcat Web Application Container
              After=network.target
              
              [Service]
              Type=forking
              ExecStart=/opt/tomcat/bin/startup.sh
              ExecStop=/opt/tomcat/bin/shutdown.sh
              User=root
              Group=root
              
              [Install]
              WantedBy=multi-user.target
              SERVICEEND
              
              systemctl daemon-reload
              systemctl enable tomcat
              EOF
  
  tags = {
    Name = "was-server-2"
  }
}

# 출력 값
output "alb_dns_name" {
  value = aws_lb.main.dns_name
  description = "The DNS name of the load balancer"
}

output "web_server_1_public_ip" {
  value = aws_instance.web_1.public_ip
  description = "Public IP of Web Server 1"
}

output "web_server_2_public_ip" {
  value = aws_instance.web_2.public_ip
  description = "Public IP of Web Server 2"
}
