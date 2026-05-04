import requests
import json

print("=== Manual Test ===\n")

# Test specific passwords
tests = [
    "password123",
    "HelloWorld", 
    "Abc123!@#",
    "weak"
]

for pwd in tests:
    try:
        r = requests.post("http://localhost:8000/check", json={"password": pwd})
        result = r.json()
        print(f"{pwd:20} -> {result['strength']} (Score: {result['score']})")
        print(f"  Suggestions: {', '.join(result['suggestions'])}\n")
    except Exception as e:
        print(f"Error: {e}")

print("=" * 40)
print("Test complete")
