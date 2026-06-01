# Bad: hardcoded credentials in source code (SEC-001)
API_KEY = "sk-proj-abc123def456ghi789jkl012mno345pqr678stu901vwx234yz"
DATABASE_PASSWORD = "super_secret_password_123"
GITHUB_TOKEN = "ghp_abc123def456ghi789jkl012mno345pqr678"

def get_data():
    headers = {"Authorization": f"Bearer {API_KEY}"}
    # fetch data with hardcoded key
