FROM ubuntu:latest

# Set non-interactive frontend for apt
ENV DEBIAN_FRONTEND=noninteractive
# Set ZSH_VERSION to avoid errors
ENV ZSH_VERSION=5.8

# Install basic tools needed for the script
RUN apt-get update && apt-get install -y \
    sudo \
    apt-utils \
    dialog \
    git \
    curl \
    wget \
    zsh \
    && rm -rf /var/lib/apt/lists/*

# Create a test user with sudo privileges
RUN useradd -m testuser && \
    echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser

# Switch to the test user
USER testuser
WORKDIR /home/testuser

# Copy the dotfiles to the container
COPY --chown=testuser:testuser . /home/testuser/dotfiles/

# Make the script executable
RUN chmod +x /home/testuser/dotfiles/scripts/setup.sh

# Command to run when container starts
CMD ["/bin/bash"]
