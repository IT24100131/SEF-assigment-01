param (
    [string]$RepoUrl
)

Write-Host "=======================================================" -ForegroundColor Cyan
Write-Host "  FishLink - Student 2 GitHub Push Setup" -ForegroundColor Cyan
Write-Host "  Branch: feature/student-2-market-pricing" -ForegroundColor Yellow
Write-Host "=======================================================" -ForegroundColor Cyan

if (-not $RepoUrl) {
    $RepoUrl = Read-Host "Enter your GitHub Repository URL (e.g. https://github.com/user/repo.git)"
}

if (-not $RepoUrl) {
    Write-Host "No repository URL provided. Exiting." -ForegroundColor Red
    exit 1
}

Write-Host "`n[1/5] Initializing Git repository..." -ForegroundColor Green
git init

Write-Host "[2/5] Creating and checking out branch: feature/student-2-market-pricing..." -ForegroundColor Green
git checkout -b "feature/student-2-market-pricing"

Write-Host "[3/5] Staging files..." -ForegroundColor Green
git add .

Write-Host "[4/5] Committing feature changes..." -ForegroundColor Green
git commit -m "feat(component-b): implement dynamic market pricing, weather safety advisory, and market intelligence agent"

Write-Host "[5/5] Pushing to $RepoUrl..." -ForegroundColor Green
git remote remove origin 2>$null
git remote add origin $RepoUrl
git branch -M "feature/student-2-market-pricing"
git push -u origin "feature/student-2-market-pricing"

Write-Host "`nSuccessfully pushed feature/student-2-market-pricing to GitHub!" -ForegroundColor Green
