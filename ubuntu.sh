#!/bin/bash

# Ubuntu Development Setup Script
# ===============================
# This script sets up a fresh Ubuntu installation for development.
# It is designed to be idempotent, meaning it can be run multiple times
# without causing issues.

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Function Definitions ---

update_system() {
    echo "--- Updating and upgrading APT packages ---"
    sudo apt update && sudo apt upgrade -y
}

install_apt_packages() {
    echo "--- Installing essential packages from APT ---"
    sudo apt install -y \
        build-essential \
        git \
        curl \
        wget \
        unzip \
        software-properties-common \
        apt-transport-https \
        autoconf \
        automake \
        libtool \
        pkg-config \
        cmake \
        gdb \
        tree \
        htop \
        jq \
        libssl-dev \
        libffi-dev \
        zlib1g-dev \
        ffmpeg \
        bat \
        fzf
}

setup_zsh() {
    echo "--- Setting up Zsh and Oh My Zsh ---"
    sudo apt install -y zsh
    
    # Run the Oh My Zsh installer non-interactively if .oh-my-zsh doesn't exist.
    if [ ! -d "${HOME}/.oh-my-zsh" ]; then
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    echo "Setting Zsh as the default shell..."
    sudo chsh -s $(which zsh) $USER

    echo "Installing Zsh plugins..."
    ZSH_CUSTOM_PLUGINS_DIR="${HOME}/.oh-my-zsh/custom/plugins"
    
    if [ ! -d "${ZSH_CUSTOM_PLUGINS_DIR}/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM_PLUGINS_DIR}/zsh-autosuggestions
    fi
    
    if [ ! -d "${ZSH_CUSTOM_PLUGINS_DIR}/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM_PLUGINS_DIR}/zsh-syntax-highlighting
    fi

    echo "Enabling plugins in .zshrc..."
    # This sed command is idempotent on a fresh Oh My Zsh install.
    # It will only match and replace the default plugin line once.
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ${HOME}/.zshrc
}

install_developer_tools() {
    echo "--- Installing additional developer tools ---"

    # Configure bat symlink
    echo "Configuring bat symlink..."
    mkdir -p ~/.local/bin
    ln -sf /usr/bin/batcat ~/.local/bin/bat

    # Install Lazygit
    if ! command -v lazygit &> /dev/null; then
        echo "Installing Lazygit..."
        LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
        tar xf lazygit.tar.gz lazygit
        sudo install lazygit /usr/local/bin
        rm lazygit.tar.gz lazygit
    else
        echo "Lazygit is already installed. Skipping."
    fi

    # Install ripgrep
    if ! command -v rg &> /dev/null; then
        echo "Installing ripgrep..."
        RIPGREP_VERSION=$(curl -s "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
        RIPGREP_DEB="ripgrep_${RIPGREP_VERSION}-1_amd64.deb"
        curl -LO "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/${RIPGREP_DEB}"
        sudo dpkg -i ${RIPGREP_DEB}
        rm ${RIPGREP_DEB}
    else
        echo "ripgrep is already installed. Skipping."
    fi

    # Install fd
    if ! command -v fd &> /dev/null; then
        echo "Installing fd..."
        FD_VERSION=$(curl -s "https://api.github.com/repos/sharkdp/fd/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
        FD_DEB="fd_${FD_VERSION}_amd64.deb"
        curl -LO "https://github.com/sharkdp/fd/releases/download/v${FD_VERSION}/${FD_DEB}"
        sudo dpkg -i ${FD_DEB}
        rm ${FD_DEB}
    else
        echo "fd is already installed. Skipping."
    fi

    # Install Neovim
    if [ ! -d "/opt/nvim-linux-x86_64" ]; then
        echo "Installing Neovim..."
        NVIM_VERSION=$(curl -s "https://api.github.com/repos/neovim/neovim/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
        curl -LO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz"
        sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
        rm nvim-linux-x86_64.tar.gz
    else
        echo "Neovim directory already exists. Skipping installation."
    fi
    
    # Add Neovim to PATH in .zshrc if it's not already there
    ZSHRC_PATH_LINE='export PATH="$PATH:/opt/nvim-linux-x86_64/bin"'
    if ! grep -qF "$ZSHRC_PATH_LINE" "${HOME}/.zshrc"; then
        echo "Adding Neovim to PATH in .zshrc"
        echo "$ZSHRC_PATH_LINE" >> "${HOME}/.zshrc"
    fi

    # Install uv (The official installer is idempotent)
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
}

install_node() {
    echo "--- Installing Node.js via nvm ---"
    export NVM_DIR="$HOME/.nvm"
    
    # Install nvm if it's not already installed
    if [ ! -d "$NVM_DIR" ]; then
        echo "Installing nvm..."
        # The script will automatically add the source lines to .zshrc
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    else
        echo "nvm is already installed. Skipping installation."
    fi

    # Source nvm to use it in the current script session
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    
    # Install the latest LTS version of Node.js
    echo "Installing latest LTS version of Node.js..."
    nvm install --lts
    nvm alias default 'lts/*' # Set the latest LTS as the default for new shells
}

install_mise() {
    echo "--- Installing mise ---"
    curl https://mise.run/zsh | sh
}

configure_git() {
    echo "--- Configuring Git ---"
    git config --global user.name "Sebastian Onycher"
    git config --global user.email "onycher@gmail.com"
    git config --global init.defaultBranch main
}

cleanup() {
    echo "--- Cleaning up ---"
    sudo apt autoremove -y
    sudo apt clean
}

main() {
    echo "Starting Ubuntu Development Setup..."
    
    update_system
    install_apt_packages
    setup_zsh
    install_developer_tools
    install_node
    install_mise
    configure_git
    cleanup
    
    echo "Setup script finished."
    echo "NOTE: Please log out and log back in for the new default shell (Zsh) to take effect."
}

# --- Script Execution ---
main
