# Gunakan Ubuntu 20.04 
FROM ubuntu:20.04

# Set non-interactive
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install .NET Core 3.1
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1 dotnet-runtime-3.1 \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js 18.x
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install Lua 5.1
RUN apt-get update && apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    liblua5.1-0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy semua file
COPY . .

# Build .NET project (jika ada .csproj)
RUN if ls *.csproj 1> /dev/null 2>&1; then \
        dotnet restore && dotnet build -c Release; \
    fi

# Install npm packages (jika ada package.json)
RUN if [ -f "package.json" ]; then \
        npm install; \
    fi

EXPOSE 8080

# Start bot
CMD ["node", "index.js"]    echo '' >> /app/start.sh && \
    echo '# Check if .env exists' >> /app/start.sh && \
    echo 'if [ ! -f ".env" ]; then' >> /app/start.sh && \
    echo '    echo "ERROR: .env file not found and TOKEN environment variable not set!"' >> /app/start.sh && \
    echo '    echo "Please either:"' >> /app/start.sh && \
    echo '    echo "  1. Set TOKEN and GuildID environment variables in Render dashboard"' >> /app/start.sh && \
    echo '    echo "  2. Or include a .env file in your repository"' >> /app/start.sh && \
    echo '    exit 1' >> /app/start.sh && \
    echo 'fi' >> /app/start.sh && \
    echo '' >> /app/start.sh && \
    echo '# Start the bot' >> /app/start.sh && \
    echo 'echo "Starting Discord bot..."' >> /app/start.sh && \
    echo 'dotnet run --project Ironbrew3.csproj' >> /app/start.sh && \
    chmod +x /app/start.sh

# Port untuk Render
EXPOSE 8080

# Buat web server sederhana untuk health check
RUN apt-get update && apt-get install -y python3 python3-pip \
    && pip3 install flask \
    && echo 'from flask import Flask\napp = Flask(__name__)\n@app.route("/")\ndef home():\n    return "Ironbrew 3 Discord Bot is running"\n@app.route("/health")\ndef health():\n    return "OK", 200\nif __name__ == "__main__":\n    app.run(host="0.0.0.0", port=8080)' > /app/health-server.py

# Gunakan script untuk menjalankan web server dan bot
RUN echo '#!/bin/bash' > /app/run-all.sh && \
    echo 'echo "Starting health check server..."' >> /app/run-all.sh && \
    echo 'python3 /app/health-server.py &' >> /app/run-all.sh && \
    echo 'sleep 2' >> /app/run-all.sh && \
    echo 'echo "Starting Discord bot..."' >> /app/run-all.sh && \
    echo '/app/start.sh' >> /app/run-all.sh && \
    chmod +x /app/run-all.sh

CMD ["/app/run-all.sh"]
