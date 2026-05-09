@echo off
echo ====================================
echo  The Grass Lady - Finish Setup
echo ====================================
echo.

echo Step 1: Extracting PowerShell 7...
if exist "%USERPROFILE%\pwsh.zip" (
    powershell -Command "Expand-Archive -Path '%USERPROFILE%\pwsh.zip' -DestinationPath '%USERPROFILE%\pwsh7' -Force"
    echo Done.
) else (
    echo Downloading PowerShell 7...
    powershell -Command "Invoke-WebRequest -Uri 'https://github.com/PowerShell/PowerShell/releases/download/v7.5.3/PowerShell-7.5.3-win-x64.zip' -OutFile '%USERPROFILE%\pwsh.zip'"
    powershell -Command "Expand-Archive -Path '%USERPROFILE%\pwsh.zip' -DestinationPath '%USERPROFILE%\pwsh7' -Force"
    echo Done.
)

echo Step 2: Setting PATH...
setx PATH "%USERPROFILE%\node-v22.15.0-win-x64;%USERPROFILE%\pwsh7;%PATH%"
set PATH=%USERPROFILE%\node-v22.15.0-win-x64;%USERPROFILE%\pwsh7;%PATH%

echo Step 3: Authenticating Claude...
echo A browser window will open. Log in with your Anthropic account.
echo.
"%USERPROFILE%\node-v22.15.0-win-x64\node_modules\@anthropic-ai\claude-code\bin\claude.exe"
echo.

echo Step 4: Starting the bot...
start "" pythonw "%USERPROFILE%\.sam\sam-deployments\clients\the-grass-lady\telegram_bot.py"

echo.
echo ====================================
echo  Setup complete!
echo ====================================
echo.
echo The bot is running. It will auto-start on reboot.
echo Darleen can message @DarleenClawdBot on Telegram.
echo.
pause
