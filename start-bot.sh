#!/bin/bash

echo "=== Ironbrew 3 Discord Bot ==="
echo "Environment: $DOTNET_ENVIRONMENT"
echo "Starting at: $(date)"

# Check if Discord token is set
if [ -z "$DISCORD_TOKEN" ]; then
    echo "ERROR: DISCORD_TOKEN environment variable is not set!"
    echo "Please set it in Render dashboard -> Environment section"
    exit 1
fi

# Export environment variables for .NET
export ASPNETCORE_ENVIRONMENT=Production
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# Build and run the application
echo "Building and running Discord bot..."
dotnet build -c Release
dotnet run --project Ironbrew3.csproj

# Keep container alive even if bot crashes
echo "Bot stopped. Restarting in 10 seconds..."
sleep 10
exec "$0"
