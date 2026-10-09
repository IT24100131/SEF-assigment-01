@echo off
echo =====================================================================
echo  RUNNING ALL 4 MEMBERS' TEST SUITES (FISHLINK AI ASSIGNMENT DEMO)
echo =====================================================================
echo.
echo [1/2] Running Complete C# xUnit Test Suite (FishLink.API.Tests)...
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --nologo
echo.
echo [2/2] Running Python Component Test Cases for All 4 Members...
python run_all_member_tests.py
echo.
pause
