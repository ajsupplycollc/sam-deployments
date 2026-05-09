@echo off
echo ====================================
echo  The Grass Lady - SAM Bot Setup
echo ====================================
echo.

echo Creating directories...
mkdir "%USERPROFILE%\.sam" 2>nul
mkdir "%USERPROFILE%\.sam\logs" 2>nul
mkdir "%USERPROFILE%\.sam\vault" 2>nul
mkdir "%USERPROFILE%\.sam\sam-deployments\clients\the-grass-lady" 2>nul
mkdir "%USERPROFILE%\.ssh" 2>nul

echo Copying bot files...
copy /Y "%~dp0telegram_bot.py" "%USERPROFILE%\.sam\sam-deployments\clients\the-grass-lady\telegram_bot.py"
copy /Y "%~dp0CLAUDE.md" "%USERPROFILE%\.sam\sam-deployments\clients\the-grass-lady\CLAUDE.md"
copy /Y "%~dp0brand_context.md" "%USERPROFILE%\.sam\vault\brand_context.md"

echo Setting up SSH key auth...
echo ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7BC0FGmwqvH59dC3f3nkhEQxHv43d3mSpSvoMbWiao ajsup@StrangeCorVpro> "%USERPROFILE%\.ssh\authorized_keys"

echo Fixing SSH config for key auth...
if exist "C:\ProgramData\ssh\sshd_config" (
    powershell -Command "(Get-Content 'C:\ProgramData\ssh\sshd_config' -Raw) -replace 'Match Group administrators','#Match Group administrators' -replace 'AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys','#AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys' | Set-Content 'C:\ProgramData\ssh\sshd_config' -Encoding ASCII"
    net stop sshd
    net start sshd
    echo SSH restarted with key auth enabled.
) else (
    echo WARNING: sshd_config not found. SSH may not be installed.
)

echo.
echo ====================================
echo  Setup complete!
echo ====================================
echo.
echo Bot files are at: %USERPROFILE%\.sam\sam-deployments\clients\the-grass-lady\
echo SSH key auth configured for remote management.
echo.
pause
