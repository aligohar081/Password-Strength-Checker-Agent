# quick_fix.ps1 - Complete fix script
Write-Host "=== FIXING PASSWORD STRENGTH CHECKER ===" -ForegroundColor Cyan

# Stop containers
Write-Host "`n1. Stopping containers..." -ForegroundColor Yellow
docker-compose down

# Remove old volume to start fresh
Write-Host "`n2. Cleaning up old data..." -ForegroundColor Yellow
docker volume rm password-strength-agent_sqlite_data -f 2>$null

# Rebuild with no cache
Write-Host "`n3. Rebuilding containers..." -ForegroundColor Yellow
docker-compose build --no-cache

# Start containers
Write-Host "`n4. Starting containers..." -ForegroundColor Yellow
docker-compose up -d

# Wait for service
Write-Host "`n5. Waiting for service to be ready..." -ForegroundColor Yellow
for ($i = 1; $i -le 15; $i++) {
    Start-Sleep -Seconds 1
    Write-Host -NoNewline "."
}
Write-Host ""

# Test health
Write-Host "`n6. Testing service health..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET -TimeoutSec 5
    Write-Host "   Service is healthy!" -ForegroundColor Green
} catch {
    Write-Host "   Service not ready yet, waiting..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}

# Run evaluation
Write-Host "`n7. Running evaluation..." -ForegroundColor Yellow
python run_eval.py

# Show final status
Write-Host "`n=== COMPLETE ===" -ForegroundColor Cyan
Write-Host "If evaluation passed, you're ready for submission!" -ForegroundColor Green
Write-Host "If still failing, run: docker-compose logs agent-api" -ForegroundColor Yellow