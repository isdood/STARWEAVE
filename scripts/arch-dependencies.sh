#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${YELLOW}Please run as root (use sudo)${NC}"
    exit 1
fi

# Function to check if a package is installed
check_package() {
    pacman -Qi "$1" &> /dev/null
    return $?
}

# Function to install a package if not installed
install_package() {
    local package="$1"
    if ! check_package "$package"; then
        echo -e "${GREEN}Installing $package...${NC}"
        pacman -S --noconfirm "$package"
    else
        echo -e "${YELLOW}$package is already installed${NC}"
    fi
}

# Install paru if not installed
if ! command -v paru &> /dev/null; then
    echo -e "${GREEN}Installing paru AUR helper...${NC}"
    pacman -S --needed --noconfirm base-devel git
    cd /tmp
    git clone https://aur.archlinux.org/paru-bin.git
    cd paru-bin
    chown -R $SUDO_USER:users .
    sudo -u $SUDO_USER makepkg -si --noconfirm
    cd ..
    rm -rf paru-bin
else
    echo -e "${YELLOW}paru is already installed${NC}"
fi

# Update system
echo -e "${GREEN}Updating system packages...${NC}"
pacman -Syu --noconfirm

# Install required dependencies
echo -e "${GREEN}Installing required dependencies...${NC}"

# System dependencies
install_package "base-devel"
install_package "git"
install_package "inotify-tools"

# Elixir/Erlang
echo -e "${GREEN}Installing Elixir and Erlang...${NC}"
paru -S --noconfirm elixir erlang

# Node.js and npm
install_package "nodejs"
install_package "npm"

# PostgreSQL
install_package "postgresql"
install_package "postgresql-libs"

# Start and enable PostgreSQL
systemctl enable --now postgresql

# Install Hex and Rebar
if ! command -v mix &> /dev/null; then
    echo -e "${YELLOW}Mix not found. Make sure Elixir is properly installed.${NC}"
else
    echo -e "${GREEN}Installing Hex and Rebar...${NC}"
    sudo -u $SUDO_USER mix local.hex --force
    sudo -u $SUDO_USER mix local.rebar --force
fi

echo -e "${GREEN}All dependencies have been installed!${NC}"
echo -e "${YELLOW}Please log out and log back in to update your PATH.${NC}"
echo -e "${YELLOW}After that, run 'mix setup' in the project directory to install Elixir dependencies.${NC}"
