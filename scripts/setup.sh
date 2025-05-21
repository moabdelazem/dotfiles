#!/bin/env bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Version
VERSION="1.0.0"

# Default values
DRY_RUN=false
BACKUP=true
VERBOSE=false

# Logging function
log() {
    local level=$1
    local message=$2
    local color=$NC
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
    esac
    
    echo -e "${color}[$level] $message${NC}"
}

# Help message
show_help() {
    cat << EOF
Dotfiles Setup Script v$VERSION

Usage: $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Show what would be done without making changes
    -n, --no-backup Skip backing up existing configurations
    --version       Show version information

This script sets up my development environment with various tools and configurations.
EOF
    exit 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -n|--no-backup)
            BACKUP=false
            shift
            ;;
        --version)
            echo "Version: $VERSION"
            exit 0
            ;;
        *)
            log "ERROR" "Unknown option: $1"
            show_help
            ;;
    esac
done

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    log "ERROR" "This script should not be run as root"
    exit 1
fi

# Check on the type of distribution 
if ! command -v apt &> /dev/null; then
    log "ERROR" "This script only works on debian based distros"
    exit 1
fi

# Backup function
backup_config() {
    local config_path=$1
    if [[ -e "$config_path" ]]; then
        local backup_path="${config_path}.backup.$(date +%Y%m%d_%H%M%S)"
        log "INFO" "Backing up $config_path to $backup_path"
        if [[ $DRY_RUN == false ]]; then
            cp -r "$config_path" "$backup_path"
        fi
    fi
}

# Progress indicator
show_progress() {
    local message=$1
    echo -n "$message... "
}

# Check if a command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# Main installation function
install_package() {
    local package=$1
    show_progress "Installing $package"
    if [[ $DRY_RUN == false ]]; then
        if ! command_exists "$package"; then
            sudo apt-get install -y "$package" > /dev/null 2>&1
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${YELLOW}Already installed${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
}

# Start installation
log "INFO" "Starting environment setup..."

# Update system
show_progress "Updating system packages"
if [[ $DRY_RUN == false ]]; then
    sudo apt-get update && sudo apt-get upgrade -y > /dev/null 2>&1
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}[DRY RUN]${NC}"
fi

# Install basic dependencies
for package in git curl wget; do
    install_package "$package"
done

# Install zsh
install_package "zsh"

# Install oh-my-zsh
if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    show_progress "Installing oh-my-zsh"
    if [[ $DRY_RUN == false ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

# Backup and clone dotfiles
if [[ $BACKUP == true ]]; then
    backup_config "$HOME/.zshrc"
fi

show_progress "Cloning dotfiles"
if [[ $DRY_RUN == false ]]; then
    if [[ ! -d "$HOME/dotfiles" ]]; then
        git clone https://github.com/moabdelazem/dotfiles.git "$HOME/dotfiles"
        cd "$HOME/dotfiles"
        mv .zshrc "$HOME/.zshrc"
        mv .tmux.conf "$HOME/.tmux.conf"
        cd ..
        rm -rf "$HOME/dotfiles"
    fi
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${YELLOW}[DRY RUN]${NC}"
fi

# Install oh-my-zsh plugins
for plugin in "zsh-syntax-highlighting" "zsh-autosuggestions"; do
    plugin_path="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/$plugin"
    if [[ ! -d "$plugin_path" ]]; then
        show_progress "Installing $plugin plugin"
        if [[ $DRY_RUN == false ]]; then
            git clone "https://github.com/zsh-users/$plugin.git" "$plugin_path" > /dev/null 2>&1
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${YELLOW}[DRY RUN]${NC}"
        fi
    fi
done

# Install CLI tools
for tool in fzf bat tmux tree; do
    install_package "$tool"
done

# Install neovim dependencies and build
show_progress "Installing neovim dependencies"
if [[ $DRY_RUN == false ]]; then
    sudo apt-get install -y ninja-build gettext libtool libtool-bin autoconf automake cmake g++ pkg-config unzip curl doxygen > /dev/null 2>&1
    echo -e "${GREEN}Done${NC}"
    
    if ! command_exists nvim; then
        show_progress "Building neovim"
        git clone https://github.com/neovim/neovim.git --depth 1
        cd neovim
        make CMAKE_BUILD_TYPE=Release
        sudo make install
        cd ..
        rm -rf neovim
        echo -e "${GREEN}Done${NC}"
    fi
else
    echo -e "${YELLOW}[DRY RUN]${NC}"
fi

# Install Node.js
if ! command_exists node; then
    show_progress "Installing Node.js"
    if [[ $DRY_RUN == false ]]; then
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        nvm install --lts
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

# Install Golang
install_package "golang"

# Install Rust
if ! command_exists rustc; then
    show_progress "Installing Rust"
    if [[ $DRY_RUN == false ]]; then
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

# Install Lazyvim Configurations
if [[ ! -d "$HOME/.config/nvim" ]]; then
    show_progress "Installing Lazyvim Configurations"
    if [[ $DRY_RUN == false ]]; then
        git clone https://github.com/LazyVim/starter.git "$HOME/.config/nvim"
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

# Install Tpm for tmux
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    show_progress "Installing Tpm for tmux"
    if [[ $DRY_RUN == false ]]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        # Install The plugins  
        tmux start-server
        tmux new-session -d
        tmux send-keys -t 0 "tmux source ~/.tmux.conf" C-m
        tmux send-keys -t 0 "tmux run-shell ~/.tmux/plugins/tpm/scripts/install_plugins.sh" C-m
        tmux kill-server
        echo -e "${GREEN}Done${NC}"
    else    
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

log "INFO" "Setup completed successfully!"

log "INFO" "run 'source ~/.zshrc' to apply changes"
if [[ $DRY_RUN == true ]]; then
    echo -e "${YELLOW}[DRY RUN] No changes were actually made${NC}"
fi
log "INFO" "We Are all Set Up Now!"
