# fix.ps1 - Complete fix script
Write-Host "=== Fixing Password Strength Agent ===" -ForegroundColor Cyan

# Stop and remove existing containers
Write-Host "`n1. Stopping and removing old containers..." -ForegroundColor Yellow
docker-compose down -v

# Remove old volume
Write-Host "`n2. Removing old volume..." -ForegroundColor Yellow
docker volume rm password-strength-agent_sqlite_data -f 2>$null

# Create missing __init__.py if needed
Write-Host "`n3. Ensuring Python package structure..." -ForegroundColor Yellow
if (-not (Test-Path "app\__init__.py")) {
    New-Item -Path "app\__init__.py" -ItemType File -Force | Out-Null
    Write-Host "   Created app/__init__.py"
}
if (-not (Test-Path "tests\__init__.py")) {
    New-Item -Path "tests\__init__.py" -ItemType File -Force | Out-Null
    Write-Host "   Created tests/__init__.py"
}

# Rebuild images
Write-Host "`n4. Rebuilding Docker images..." -ForegroundColor Yellow
docker-compose build --no-cache

# Start services
Write-Host "`n5. Starting services..." -ForegroundColor Yellow
docker-compose up -d

# Wait for service to be ready
Write-Host "`n6. Waiting for service to be ready..." -ForegroundColor Yellow
$maxAttempts = 30
$attempt = 0
$serviceReady = $false

while ($attempt -lt $maxAttempts -and -not $serviceReady) {
    $attempt++
    Write-Host -NoNewline "   Attempt $attempt/$maxAttempts... "
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8000/health" -Method GET -TimeoutSec 2 -ErrorAction Stop
        if ($response.status -eq "healthy") {
            $serviceReady = $true
            Write-Host "✅ READY!" -ForegroundColor Green
        } else {
            Write-Host "⏳"
        }
    } catch {
        Write-Host "⏳"
    }
    
    if (-not $serviceReady -and $attempt -lt $maxAttempts) {
        Start-Sleep -Seconds 1
    }
}

if ($serviceReady) {
    Write-Host "`n✅ Service is running!" -ForegroundColor Green
    
    # Test the API
    Write-Host "`n=== Testing API ===" -ForegroundColor Cyan
    
    Write-Host "`nTesting weak password..." -ForegroundColor Yellow
    $result = Invoke-RestMethod -Uri "http://localhost:8000/check" -Method POST -ContentType "application/json" -Body '{"password":"123"}'
    Write-Host "  Strength: $($result.strength)" -ForegroundColor Red
    Write-Host "  Score: $($result.score)"
    Write-Host "  Suggestions: $($result.suggestions -join ', ')"
    
    Write-Host "`nTesting strong password..." -ForegroundColor Yellow
    $result = Invoke-RestMethod -Uri "http://localhost:8000/check" -Method POST -ContentType "application/json" -Body '{"password":"MySecureP@ss123"}'
    Write-Host "  Strength: $($result.strength)" -ForegroundColor Green
    Write-Host "  Score: $($result.score)"
    Write-Host "  Suggestions: $($result.suggestions -join ', ')"
    
    Write-Host "`nGetting history..." -ForegroundColor Yellow
    $history = Invoke-RestMethod -Uri "http://localhost:8000/history" -Method GET
    Write-Host "  Total checks: $($history.checks.Count)" -ForegroundColor Cyan
    
    Write-Host "`n=== SUCCESS! ===" -ForegroundColor Green
} else {
    Write-Host "`n❌ Service failed to start. Checking logs..." -ForegroundColor Red
    docker-compose logs --tail=50 agent-api
}

Write-Host "`nUseful commands:" -ForegroundColor Yellow
Write-Host "  View logs: docker-compose logs -f"
Write-Host "  Stop: docker-compose down"
Write-Host "  Restart: docker-compose restart"