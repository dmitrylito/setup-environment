#!/bin/sh

set -xe

# ----------------------------------------------------------------
# TARGET VERSION: v0.11.5
# ----------------------------------------------------------------
NVIM_VERSION=v0.11.5

# Check if I'm connected as root user. If not, exit.
if [ "$(id -u)" != "0" ]; then
  echo "Sorry, you are not root."
  exit 1
fi

# Updating libraries
cd "${HOME}"

# Installing neovim dependencies
apt-get update
apt-get install -y \
  git \
  curl \
  zip \
  libluajit-5.1-dev \
  ripgrep \
  fd-find

# Installing lazygit
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit

# ------------------------------------------------------
# NEOVIM INSTALLATION (x86_64 AppImage Only)
# ------------------------------------------------------

echo "Installing Neovim ${NVIM_VERSION} (AppImage)..."

# 1. Download
# Note: We use the specific tag v0.11.5
curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim.appimage"
chmod u+x nvim.appimage

# 2. Extract
./nvim.appimage --appimage-extract

# 3. Verify it runs
./squashfs-root/AppRun --version

# 4. Clean up artifacts
rm nvim.appimage

# 5. Move to Global Location
rm -rf /squashfs-root
mv squashfs-root /

# 6. Link binary to /usr/bin/nvim
ln -sf /squashfs-root/AppRun /usr/bin/nvim

echo "Neovim installation complete."
nvim --version
