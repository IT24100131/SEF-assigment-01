@echo off
echo =====================================================================
echo  RUNNING TESTS FOR MEMBER 2: QUALITY ASSESSMENT & MARKET PRICING
echo =====================================================================
echo.
echo [1/2] Running C# xUnit Integration Suite (FishLink.API.Tests)...
dotnet test .\FishLink.API.Tests\FishLink.API.Tests.csproj --filter "Member2" --nologo
echo.
echo [2/2] Running Python Component Test Cases...
python member2_tests.py
echo.
pause
