#!/bin/bash
echo "Enabling Tailscale SSH..."
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
if [ -x "$TS" ]; then
    sudo "$TS" up --ssh
    echo "Done. Tailscale SSH is enabled."
else
    echo "Tailscale app not found. Install it first."
fi
