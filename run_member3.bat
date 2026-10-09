@echo off
echo =====================================================================
echo  RUNNING TESTS FOR MEMBER 3: BUYER MATCHING & BIDDING ENGINE
echo =====================================================================
echo.
echo [1/2] Running C# xUnit Integration Suite (FishLink.API.Tests)...
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member3" --nologo
echo.
echo [2/2] Running Python Component Test Cases...
python member3_tests.py
echo.
pause
