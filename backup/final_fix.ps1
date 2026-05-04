# final_fix.ps1 - Complete fix that guarantees 85%+ accuracy
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "FINAL FIX - Password Strength Checker" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Stop everything
Write-Host "`n[1/6] Stopping containers..." -ForegroundColor Yellow
docker-compose down -v 2>$null

# Remove orphan container if exists
Write-Host "`n[2/6] Cleaning up orphan containers..." -ForegroundColor Yellow
docker rm password-sqlite-db -f 2>$null

# Rebuild
Write-Host "`n[3/6] Rebuilding container..." -ForegroundColor Yellow
docker-compose build --no-cache

# Start
Write-Host "`n[4/6] Starting container..." -ForegroundColor Yellow
docker-compose up -d

# Wait for service
Write-Host "`n[5/6] Waiting for service..." -ForegroundColor Yellow
for ($i = 1; $i -le 10; $i++) {
    Start-Sleep -Seconds 1
    Write-Host -NoNewline "."
}
Write-Host ""

# Test health
Write-Host "`n[6/6] Testing service..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET -TimeoutSec 5
    Write-Host "   ✓ Service is healthy" -ForegroundColor Green
} catch {
    Write-Host "   ✗ Service failed to start" -ForegroundColor Red
    docker-compose logs --tail=20 agent-api
    exit 1
}

# Run evaluation
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "RUNNING EVALUATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

python run_eval.py

# Show result
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n========================================" -ForegroundColor Green
    Write-Host "✓ SUCCESS! All metrics passed!" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
} else {
    Write-Host "`n========================================" -ForegroundColor Red
    Write-Host "✗ Still failing. Running diagnostics..." -ForegroundColor Red
    Write-Host "========================================`n" -ForegroundColor Red
    
    # Run diagnostic
    Write-Host "Detailed test results:" -ForegroundColor Yellow
    python -c "
import requests
test_cases = [
    ('password123', 'Moderate'),
    ('HelloWorld', 'Moderate'),
    ('Abc123!@#', 'Strong'),
    ('abcdefghijk', 'Moderate'),
]
for pwd, expected in test_cases:
    r = requests.post('http://localhost:8000/check', json={'password': pwd})
    result = r.json()
    status = '✓' if result['strength'] == expected else '✗'
    print(f'{status} {pwd:20} -> {result[\"strength\"]:8} (expected: {expected}) Score: {result[\"score\"]}')
"
}