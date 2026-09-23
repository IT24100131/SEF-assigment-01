@echo off
setlocal
echo =======================================================
echo   FishLink - Student 1 GitHub Push Setup
echo   Branch: feature/student-1-catch-quality
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

echo [2/5] Setting up branch: feature/student-1-catch-quality...
git checkout -b feature/student-1-catch-quality

echo [3/5] Adding files...
git add .

echo [4/5] Committing Student 1 feature work...
git commit -m "feat(component-a): implement catch ingestion, pier inspection, quality verification and fraud detection agent"

echo [5/5] Adding remote and pushing to GitHub...
git remote remove origin >nul 2>&1
git remote add origin %REPO_URL%
git branch -M feature/student-1-catch-quality
git push -u origin feature/student-1-catch-quality

echo.
echo =======================================================
echo   Push Complete! Check your GitHub repository.
echo =======================================================
pause
