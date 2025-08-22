
---
# 3-Tier AWS Web Architecture

## 1. 프로젝트 개요

AWS 기반 Spring Boot 웹 애플리케이션 고가용성 아키텍처 구축 및 테스트를 위한 프로젝트 입니다.

### 주요 목표
- 웹 애플리케이션의 고가용성 및 확장성 검증
- 부하 테스트(Locust)를 통한 성능 및 장애 대응 프로세스 점검
- Scouter 도구를 통한 WAS 성능 모니터링 및 분석

---

## 2. 주요 기술 및 아키텍처

<img width="602" height="384" alt="Image" src="https://github.com/user-attachments/assets/21d54074-4f1e-400e-9cb1-b653da03f084" />


- 주요 기술 : AWS, Terraform, Spring Boot, Locust, Nginx, Tomcat, MySQL 

- 주요 구성 요소
    - ALB: 외부 트래픽을 Web Server 1,2로 분산
    - NAT instance : Private 서브넷 아웃바운드 트래픽 통신
    - Web Server: Nginx로 구성, WAS Server 1,2 로 프록시
    - WAS Server: Tomcat + Spring Boot(WAR) 배포, 애플리케이션 로직 처리
    - Monitor: Scouter Collector를 통해 WAS의 CPU, TPS, xlog 등을 모니터링



## 3. 배포/실행 방법

1. **환경 준비**  
   - AWS CLI/Access Key, Terraform 설치

2. **변수파일 수정(`variables.tf` 혹은 `terraform.tfvars`)**
   - 원하는 VPC/인스턴스 타입, DB 비밀번호 등 입력

3. **Terraform 명령어 실행**
   ```bash
   terraform init
   terraform plan
   terraform apply
