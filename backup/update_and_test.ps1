# update_and_test.ps1
Write-Host "=== Updating Password Strength Checker ===" -ForegroundColor Cyan

# Stop the container
Write-Host "`n1. Stopping container..." -ForegroundColor Yellow
docker-compose stop

# Rebuild (this will pick up the changes)
Write-Host "`n2. Rebuilding with improved logic..." -ForegroundColor Yellow
docker-compose build --no-cache

# Start container
Write-Host "`n3. Starting container..." -ForegroundColor Yellow
docker-compose up -d

# Wait for service
Write-Host "`n4. Waiting for service..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Test health
Write-Host "`n5. Testing health..." -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET
Write-Host "   Status: $($health.status)" -ForegroundColor Green

# Run evaluation
Write-Host "`n6. Running evaluation with improved logic..." -ForegroundColor Yellow
python run_eval.py

Write-Host "`n=== Done ===" -ForegroundColor Cyan