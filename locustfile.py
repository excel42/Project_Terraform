from locust import HttpUser, task

class ServerTest(HttpUser):
    @task
    def api_test(self):
        self.client.get("/api/status") # 상태 응답 테스트
        self.client.get("/api/resource") # 리소스 집약적 API 테스트
        self.client.get("/api/data") # 데이터 처리 API 테스트
        self.client.get("/actuator/health") # 서버 상태 확인