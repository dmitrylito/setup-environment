#!/bin/bash
set -e

# 1. ROBUST USER DETECTION
# We prioritize the env var passed from Docker, then the current user.
if [ -n "$containerUser" ]; then
  TARGET_USER="$containerUser"
else
  TARGET_USER=$(whoami)
fi

# Define Home Directory explicitly to avoid confusion
TARGET_HOME="/home/${TARGET_USER}"
BASEDIR=$(dirname "$0")

# Create logs directory if it doesn't exist
mkdir -p "${BASEDIR}/logs"
LOG_FILE="${BASEDIR}/logs/install.log"

SUDO=""

# Write function that prints a log (including time) to the console and to a file.
function log() {
  echo "$(date) - $1" | tee -a "${LOG_FILE}"
}

function create_folder() {
  if [[ ! -d "$1" ]]; then
    mkdir -p "$1"
    log "Folder $1 created."
  fi
}

# Check if a program exists
function program_exists() {
  command -v "$1" >/dev/null 2>&1
}

function help() {
  echo "Usage: ./install.sh [OPTIONS]"
  echo "Options:"
  echo "  -p, --package <package_name>  Install only the specified package."
  echo "  -d, --dotfiles                Install dotfiles."
  echo "  -h, --help                    Show this help message."
  exit 0
}

# Check if sudo exists (and is needed)
if [ "$(id -u)" -ne 0 ] && program_exists "sudo"; then
  SUDO="sudo"
fi

# Argument Parsing
packages=()
prev_package=false
install_packages=false # Default to false unless -p or env var is set
install_dotfiles=false

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
  -p | --package)
    install_packages=true
    prev_package=true
    shift
    ;;
  -h | --help)
    help
    ;;
  -d | --dotfiles)
    install_dotfiles=true
    shift
    ;;
  *)
    if [[ $prev_package == true ]]; then
      packages+=("$1")
    else
      echo "Error: Invalid argument $1."
      exit 1
    fi
    shift
    ;;
  esac
done

# Check if the DOTFILE_PACKAGES env variable exists
if [[ -n "${DOTFILE_PACKAGES}" ]]; then
  # Split string into array
  IFS=' ' read -r -a packages <<<"${DOTFILE_PACKAGES}"
  install_packages=true
fi

# --- PACKAGE INSTALLATION ---
if [[ "${install_packages}" == "true" ]]; then
  log "Installation of packages..."

  # Ensure package scripts are executable
  chmod +x "${BASEDIR}"/packages/*.sh 2>/dev/null || true

  for file in "${BASEDIR}"/packages/*.sh; do
    # Handle case where no files exist
    [ -e "$file" ] || continue

    filename=$(basename "$file")
    program="${filename%.*}"

    # Filter logic
    if [[ ${#packages[@]} -gt 0 ]]; then
      # Check if program is in the list
      match=false
      for pkg in "${packages[@]}"; do
        if [[ "$pkg" == "$program" ]]; then
          match=true
          break
        fi
      done

      if [[ "$match" == "false" ]]; then
        log "Skipping $filename (not requested)."
        continue
      fi
    else
      # If no packages specified but -p used without args (or just implicit run), install all?
      # Based on your logic: empty list means install all if install_packages is set via logic I added?
      # Actually, your original logic implied empty packages list = install everything.
      log "Installing $program (all mode)"
    fi

    # Install Logic
    if ! program_exists "${program}"; then
      echo "Installing $file..."
      # Executing script.
      # Note: We use $SUDO here, assuming the script handles apt-get.
      ${SUDO} "$file" 2>&1 | tee "${BASEDIR}/logs/${filename}.log"
    else
      echo "Skipping $file: Program '$program' already installed."
    fi
  done

  log "Configuration of folders:"
  # Create config dotfiles ~/.config ~/.local/ ~/.cache/
  for folder in ".config" ".local" ".cache"; do
    folder_absolute="${TARGET_HOME}/${folder}"
    create_folder "${folder_absolute}"

    # 2. FIXED PERMISSIONS
    # Only chown if we are running as root.
    # If we are already the user, permissions are automatically correct.
    if [ "$(id -u)" -eq 0 ]; then
      chown -R "${TARGET_USER}:${TARGET_USER}" "${folder_absolute}"
    fi
  done
fi

# --- DOTFILES (STOW) ---
if [ "${install_dotfiles}" == "true" ]; then
  if ! program_exists "stow"; then
    log "Error: 'stow' is not installed. Cannot link dotfiles."
    exit 1
  fi

  log "Linking dotfiles..."

  # Ensure we are linking from the correct directory
  DOTFILES_DIR="${BASEDIR}/dotfiles"

  if [ -d "$DOTFILES_DIR" ]; then
    # Unlink old
    stow --dir="$DOTFILES_DIR" --target="$TARGET_HOME" --verbose -D . 2>/dev/null || true
    # Link new
    stow --dir="$DOTFILES_DIR" --target="$TARGET_HOME" --verbose .
    log "Dotfiles linked successfully."
  else
    log "Error: Directory $DOTFILES_DIR not found."
    exit 1
  fi
fi
