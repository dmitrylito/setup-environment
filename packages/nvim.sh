#!/bin/sh

set -xe

# Set to "stable" to always get the latest release (currently > 0.10.2)
NVIM_VERSION=stable

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

# Installing lazygit (Dynamic latest version fetch)
LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
tar xf lazygit.tar.gz lazygit
install lazygit /usr/local/bin
rm lazygit.tar.gz lazygit

# ------------------------------------------------------
# NEOVIM INSTALLATION
# ------------------------------------------------------

# 1. ARM / AARCH64 (Build from source)
if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm" ]; then
  echo "Detected ARM architecture. Building from source..."

  # Install build prerequisites
  apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl doxygen

  # Clone and build
  rm -rf neovim # Clean previous builds if any
  git clone https://github.com/neovim/neovim.git
  cd neovim
  git checkout ${NVIM_VERSION}
  make CMAKE_BUILD_TYPE=RelWithDebInfo
  make install
  cd -
  rm -rf neovim

# 2. X86_64 (AppImage)
else
  echo "Detected x86_64 architecture. Installing via AppImage..."

  # Download the release defined by NVIM_VERSION (stable)
  curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim.appimage"
  chmod u+x nvim.appimage

  # Extract
  ./nvim.appimage --appimage-extract

  # Verify it runs
  ./squashfs-root/AppRun --version

  rm nvim.appimage

  # Exposing nvim globally
  # Remove existing installation to avoid conflicts
  rm -rf /squashfs-root
  mv squashfs-root /

  # Link binary (overwrite if exists)
  ln -sf /squashfs-root/AppRun /usr/bin/nvim
fi

echo "Neovim installation complete."
nvim --version
