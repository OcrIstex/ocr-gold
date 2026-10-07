#!/usr/bin/env bash

set -euo pipefail

export PATH="$HOME/.nix-profile/bin:$PATH"

# Install nix
# Enable flakes + the new nix CLI
sudo chown $USERNAME ~/.config/
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf

# Provides nix-shell
sudo apt update && sudo apt upgrade -y
sudo apt install curl -y

sh <(curl -L https://nixos.org/nix/install) --no-daemon --yes
. ~/.nix-profile/etc/profile.d/nix.sh

nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs-unstable
nix-channel --update

echo 'export PATH="$HOME/.nix-profile/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.nix-profile/bin:$PATH"' >> ~/.profile

nix registry add datalab "$WORKSPACE_DIR/$(basename ${GIT_REPOSITORY:-datalab})"
