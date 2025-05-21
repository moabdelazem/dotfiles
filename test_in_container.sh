#!/bin/bash

# This script helps test the dotfiles setup in a Docker container

echo "🚀 Starting Dotfiles Container Test"

# Build and run the test container
if command -v docker-compose &> /dev/null; then
    docker-compose up --build
elif command -v docker &> /dev/null; then
    docker build -t dotfiles-test .
    docker run -it --rm \
        -v "$(pwd):/home/testuser/dotfiles" \
        dotfiles-test \
        /bin/bash -c "cd /home/testuser && /home/testuser/dotfiles/scripts/container_setup.sh && /bin/bash"
else
    echo "❌ Error: Docker is not installed. Please install Docker to test in a container."
    exit 1
fi
