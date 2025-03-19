from locust import HttpUser, task

class ServerTest(HttpUser):
    @task
    def api_test(self):
        self.client.get("/api/status")
        self.client.get("/api/resource")
        self.client.get("/api/data")
        self.client.get("/actuator/health")