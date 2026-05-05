#!/bin/bash
echo "Enabling Tailscale SSH..."
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS" ]; then
    sudo "$TS" up --ssh --accept-routes --reset
    if [ $? -eq 0 ]; then
        echo "Done. Tailscale SSH is enabled."
    else
        echo "Failed. Ask Jereme."
    fi
else
    echo "Tailscale app not found. Install it first."
fi
