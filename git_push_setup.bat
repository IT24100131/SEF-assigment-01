@echo off
setlocal
echo =======================================================
echo   FishLink - Student 2 GitHub Push Setup
echo   Branch: feature/student-2-market-pricing
echo =======================================================

if "%~1"=="" (
    echo Error: Please provide your GitHub repository URL.
    echo Usage: git_push_setup.bat https://github.com/USERNAME/REPO.git
    echo.
    set /p REPO_URL="Enter your GitHub Repository URL: "
) else (
    set REPO_URL=%~1
)

if "%REPO_URL%"=="" (
    echo No repository URL provided. Aborting.
    pause
    exit /b 1
)

echo.
echo [1/5] Initializing Git...
git init

echo [2/5] Setting up branch: feature/student-2-market-pricing...
git checkout -b feature/student-2-market-pricing

echo [3/5] Adding files...
git add .

echo [4/5] Committing Student 2 feature work...
git commit -m "feat(component-b): implement dynamic market pricing, weather safety advisory, and market intelligence agent"

echo [5/5] Adding remote and pushing to GitHub...
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%
git branch -M feature/student-2-market-pricing
git push -u origin feature/student-2-market-pricing

echo.
echo =======================================================
echo   Push Complete! Check your GitHub repository.
echo =======================================================
pause
