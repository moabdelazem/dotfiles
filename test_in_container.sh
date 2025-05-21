#!/bin/bash

# This script helps test the dotfiles setup in a Docker container

echo "🚀 Starting Dotfiles Container Test"
echo "🔍 Checking for common environment issues..."

# Check if zsh is installed
if ! command -v zsh &> /dev/null; then
    echo "⚠️  Warning: zsh is not installed on the host. This will not affect container testing."
fi

echo "📦 Building container environment..."

# Build and run the test container with verbose output
if command -v docker-compose &> /dev/null; then
    echo "🐳 Using docker-compose to build and run the test environment"
    docker-compose up --build
elif command -v docker &> /dev/null; then
    echo "🐳 Using docker to build and run the test environment"
    docker build -t dotfiles-test .
    docker run -it --rm \
        -v "$(pwd):/home/testuser/dotfiles" \
        -e "TERM=$TERM" \
        dotfiles-test \
        /bin/bash -c "cd /home/testuser && echo '🔧 Running container setup script...' && /home/testuser/dotfiles/scripts/container_setup.sh && echo '✅ Setup complete! Starting interactive shell...' && /bin/bash"
else
    echo "❌ Error: Docker is not installed. Please install Docker to test in a container."
    exit 1
fi
