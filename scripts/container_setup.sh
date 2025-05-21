#!/bin/env bash

# Container-friendly version of setup script
# This is designed to test the setup in a container environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Version
VERSION="1.0.0-container"

# Default values
DRY_RUN=false
BACKUP=true
VERBOSE=false
CONTAINER_MODE=true

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
Dotfiles Container Test Script v$VERSION

Usage: $0 [OPTIONS]

Options:
    -h, --help      Show this help message
    -v, --verbose   Enable verbose output
    -d, --dry-run   Show what would be done without making changes
    -n, --no-backup Skip backing up existing configurations
    --version       Show version information

This script tests the setup of your development environment in a container.
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

# Check package manager - support both apt and apt-get for wider container compatibility
if command -v apt &> /dev/null; then
    PKG_MGR="apt"
elif command -v apt-get &> /dev/null; then
    PKG_MGR="apt-get"
else
    log "ERROR" "This script requires apt or apt-get package manager"
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
            if [[ $VERBOSE == true ]]; then
                sudo $PKG_MGR install -y "$package"
            else
                sudo $PKG_MGR install -y "$package" > /dev/null 2>&1
            fi
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${YELLOW}Already installed${NC}"
        fi
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
}

# This function checks if we can minimize build operations in container
should_skip_heavy_builds() {
    if [[ $CONTAINER_MODE == true ]]; then
        return 0  # true in bash test context
    else
        return 1  # false in bash test context
    fi
}

# Start installation
log "INFO" "Starting container test environment setup..."
log "INFO" "Running in container-optimized mode"

# Update system - minimal in container
show_progress "Updating package lists"
if [[ $DRY_RUN == false ]]; then
    if [[ $VERBOSE == true ]]; then
        sudo $PKG_MGR update
    else
        sudo $PKG_MGR update > /dev/null 2>&1
    fi
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
        # Use RUNZSH=no to prevent oh-my-zsh from changing the shell
        export ZSH_VERSION=5.8  # Set a dummy ZSH_VERSION to avoid the error
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

# Backup and set up dotfiles
if [[ $BACKUP == true ]]; then
    backup_config "$HOME/.zshrc"
    backup_config "$HOME/.tmux.conf"
fi

show_progress "Setting up dotfiles"
if [[ $DRY_RUN == false ]]; then
    # In container mode, we already have the dotfiles directory
    cp -f "$HOME/dotfiles/zshrc" "$HOME/.zshrc"
    cp -f "$HOME/dotfiles/tmux.conf" "$HOME/.tmux.conf"
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
            if [[ $VERBOSE == true ]]; then
                git clone "https://github.com/zsh-users/$plugin.git" "$plugin_path" 
            else
                git clone "https://github.com/zsh-users/$plugin.git" "$plugin_path" > /dev/null 2>&1
            fi
            echo -e "${GREEN}Done${NC}"
        else
            echo -e "${YELLOW}[DRY RUN]${NC}"
        fi
    fi
done

# Install lightweight CLI tools for container testing
for tool in tmux tree; do
    install_package "$tool"
done

# Skip heavy builds in container mode
if ! should_skip_heavy_builds; then
    # Install neovim dependencies and build
    show_progress "Installing neovim dependencies"
    if [[ $DRY_RUN == false ]]; then
        sudo $PKG_MGR install -y ninja-build gettext libtool autoconf automake cmake g++ pkg-config unzip curl > /dev/null 2>&1
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
else
    log "INFO" "Skipping Neovim build in container mode"
fi

# Install Tpm for tmux
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
    show_progress "Installing Tpm for tmux"
    if [[ $DRY_RUN == false ]]; then
        git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
        # Install The plugins - adjusted for container
        if command_exists tmux; then
            tmux start-server
            tmux new-session -d
            tmux send-keys -t 0 "tmux source ~/.tmux.conf" C-m
            tmux send-keys -t 0 "tmux run-shell ~/.tmux/plugins/tpm/scripts/install_plugins.sh" C-m
            tmux kill-server
        fi
        echo -e "${GREEN}Done${NC}"
    else    
        echo -e "${YELLOW}[DRY RUN]${NC}"
    fi
fi

log "INFO" "Container test setup completed successfully!"

log "INFO" "To test your dotfiles in this container, run:"
echo "   chsh -s $(which zsh)"
echo "   zsh"
echo "   source ~/.zshrc"

if [[ $DRY_RUN == true ]]; then
    echo -e "${YELLOW}[DRY RUN] No changes were actually made${NC}"
fi

log "INFO" "Container test environment is ready!"
