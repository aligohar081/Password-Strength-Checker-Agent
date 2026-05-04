#!/usr/bin/env python3
import requests
import json
import sys
import time
import os

API_URL = os.getenv('API_URL', 'http://localhost:8000')
OUTPUT_FILE = 'eval_results.json'

def load_test_cases():
    """Load test cases from JSON file - handles BOM automatically"""
    with open('tests/test_passwords.json', 'r', encoding='utf-8-sig') as f:
        data = json.load(f)
    return data['test_cases']

def test_strength_accuracy(test_cases):
    """Test accuracy of strength classification"""
    correct = 0
    total = len(test_cases)
    
    print(f"\nTesting {total} passwords...\n")
    
    for test in test_cases:
        password = test['password']
        expected = test['expected_strength']
        
        try:
            response = requests.post(
                f"{API_URL}/check",
                json={"password": password},
                timeout=5
            )
            result = response.json()
            actual = result['strength']
            
            is_correct = actual == expected
            if is_correct:
                correct += 1
                print(f"  ✅ {password:20} -> {actual}")
            else:
                print(f"  ❌ {password:20} -> {actual:8} (expected: {expected})")
                
        except Exception as e:
            print(f"  ❌ Error testing {password}: {e}")
    
    accuracy = correct / total if total > 0 else 0
    return accuracy, correct, total

def check_service_health():
    """Check if API service is healthy"""
    for i in range(5):
        try:
            response = requests.get(f"{API_URL}/health", timeout=2)
            if response.status_code == 200:
                return True
        except:
            pass
        time.sleep(1)
    return False

def main():
    print("🔍 Password Strength Agent Evaluation")
    print("=" * 50)
    
    # Check service
    print("\n1. Checking service health...")
    if not check_service_health():
        print("   ❌ API service not available")
        print("   Run: docker-compose up -d")
        sys.exit(1)
    print("   ✅ Service is healthy")
    
    # Load test cases
    print("\n2. Loading test cases...")
    try:
        test_cases = load_test_cases()
        print(f"   ✅ Loaded {len(test_cases)} test cases")
    except Exception as e:
        print(f"   ❌ Error loading test cases: {e}")
        sys.exit(1)
    
    # Test accuracy
    print("\n3. Testing strength accuracy...")
    accuracy, correct, total = test_strength_accuracy(test_cases)
    print(f"\n   Accuracy: {accuracy:.1%} ({correct}/{total})")
    
    # Check threshold
    threshold = 0.85
    passed = accuracy >= threshold
    
    # Save results
    results = {
        "metrics": [
            {
                "name": "strength_accuracy",
                "score": accuracy,
                "threshold": threshold,
                "pass": passed
            }
        ],
        "overall_pass": passed
    }
    
    with open(OUTPUT_FILE, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"\n📄 Results saved to {OUTPUT_FILE}")
    print(f"\n   Required threshold: 85%")
    print(f"   Achieved: {accuracy:.1%}")
    
    if passed:
        print("\n✅ ALL METRICS PASSED! CI pipeline successful.")
        sys.exit(0)
    else:
        print("\n❌ SOME METRICS FAILED! Need 85% accuracy.")
        sys.exit(1)

if __name__ == "__main__":
    main()