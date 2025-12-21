#!/bin/bash
set -e
git init
git add .
git config user.name "Matt Rickard"
git config user.email "mjr6140@gmail.com"
git commit -m "Initial commit of Nix configurations"
git branch -M main
echo "Git setup complete."
