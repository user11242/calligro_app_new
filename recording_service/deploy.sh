#!/usr/bin/env bash
set -e

echo "=================================================="
echo "🚀 Setting up Calligro LiveKit Recording Worker..."
echo "=================================================="

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    sudo usermod -aG docker $USER
fi

# Check for .env
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "📝 Creating .env from .env.example..."
        cp .env.example .env
        echo "⚠️ Please edit .env with your LiveKit and Cloudflare R2 credentials!"
        exit 1
    fi
fi

# Pull and start containers
echo "🐳 Pulling latest LiveKit Egress image..."
docker compose pull

echo "▶️ Starting recording worker daemon in background..."
docker compose up -d

echo "=================================================="
echo "✅ Calligro LiveKit Recording Worker is RUNNING!"
echo "   Status: docker compose ps"
echo "   Logs:   docker compose logs -f egress"
echo "=================================================="
