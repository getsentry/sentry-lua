#!/bin/bash

# Redis + Sentry Lua Integration Test Runner

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Starting Redis + Sentry Lua Integration Test"
echo "==============================================="

# Function to cleanup on exit
cleanup() {
    echo "🧹 Cleaning up containers..."
    docker-compose down -v --remove-orphans > /dev/null 2>&1 || true
}

# Set trap to cleanup on script exit
trap cleanup EXIT

# Check if docker and docker-compose are available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose is not installed or not in PATH"
    exit 1
fi

# Build and start containers
echo "🏗️  Building Docker images..."
docker-compose build

echo "🚀 Starting Redis server..."
docker-compose up -d redis

# Wait for Redis to be ready
echo "⏳ Waiting for Redis to be ready..."
timeout=30
counter=0
while ! docker-compose exec -T redis redis-cli ping > /dev/null 2>&1; do
    counter=$((counter + 1))
    if [ $counter -gt $timeout ]; then
        echo "❌ Timeout waiting for Redis to start"
        docker-compose logs redis
        exit 1
    fi
    sleep 1
done

echo "✅ Redis is ready!"

# Run the test
echo "🧪 Running Sentry + Redis Lua integration test..."
echo "=================================================="

if docker-compose run --rm sentry-test; then
    echo "=================================================="
    echo "✅ All tests completed successfully!"
    echo "🎉 Redis Lua scripts executed and Sentry events captured"
else
    echo "=================================================="
    echo "❌ Tests failed"
    echo "📋 Container logs:"
    docker-compose logs sentry-test
    exit 1
fi

echo "🏁 Test run complete"