#!/bin/bash

# Exit on error and print each command
set -e
set -x

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting Erlang and Elixir installation with asdf...${NC}"

# Function to print section headers
section() {
    echo -e "\n${GREEN}=== $1 ===${NC}"
}

# Install asdf if not already installed
section "Installing asdf version manager"
if ! command -v asdf &> /dev/null; then
    echo "Installing asdf..."
    paru -S --noconfirm asdf-vm
    
    # Add asdf to shell configuration
    echo -e '\n# asdf version manager\n. /opt/asdf-vm/asdf.sh' >> ~/.bashrc
    source ~/.bashrc
else
    echo "asdf is already installed."
fi

# Install required dependencies
section "Installing required dependencies"
sudo pacman -S --noconfirm --needed base-devel unzip ncurses openssl libyaml \
    libxslt libtool readline unixodbc make automake autoconf inetutils fop

# Install Erlang
section "Installing Erlang 27.3.4"
asdf plugin add erlang https://github.com/asdf-vm/asdf-erlang.git || echo "Erlang plugin already exists"
ERLANG_VERSION="27.3.4"

# Check if Erlang is already installed
if ! asdf list erlang | grep -q "$ERLANG_VERSION"; then
    echo "Installing Erlang $ERLANG_VERSION..."
    asdf install erlang $ERLANG_VERSION
    asdf global erlang $ERLANG_VERSION
else
    echo "Erlang $ERLANG_VERSION is already installed."
fi

# Install Elixir
section "Installing Elixir 1.18.4"
asdf plugin add elixir https://github.com/asdf-vm/asdf-elixir.git || echo "Elixir plugin already exists"
ELIXIR_VERSION="1.18.4-otp-27"

# Check if Elixir is already installed
if ! asdf list elixir | grep -q "$ELIXIR_VERSION"; then
    echo "Installing Elixir $ELIXIR_VERSION..."
    asdf install elixir $ELIXIR_VERSION
    asdf global elixir $ELIXIR_VERSION
else
    echo "Elixir $ELIXIR_VERSION is already installed."
fi

# Verify installations
section "Verifying installations"
echo -e "\n${YELLOW}=== Installation Summary ===${NC}"
echo "Erlang version:" $(erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().'  -noshell)
echo "Elixir version:" $(elixir --version | head -n 1)

echo -e "\n${GREEN}Installation completed successfully!${NC}"
echo -e "Please restart your terminal or run 'source ~/.bashrc' to update your environment."
