#!/bin/bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK7BC0FGmwqvH59dC3f3nkhEQxHv43d3mSpSvoMbWiao ajsup@StrangeCorVpro" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
echo "Done. SAM SSH key added."
