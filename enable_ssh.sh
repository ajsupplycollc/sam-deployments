#!/bin/bash
echo "Enabling macOS Remote Login (SSH)..."
sudo systemsetup -setremotelogin on
if [ $? -eq 0 ]; then
    echo "Done. SSH is enabled."
    echo "Username: $(whoami)"
    echo "Connect with: ssh $(whoami)@$(ipconfig getifaddr en0 2>/dev/null || echo '<tailscale-ip>')"
else
    echo "Failed. Trying alternate method..."
    sudo launchctl load -w /System/Library/LaunchDaemons/ssh.plist 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "Done. SSH is enabled via launchctl."
    else
        echo "Failed both methods. Ask Jereme."
    fi
fi
