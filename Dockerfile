# Gunakan .NET 3.1 SDK (masih tersedia dan kompatibel dengan 3.0)
FROM mcr.microsoft.com/dotnet/sdk:3.1 AS build

# Install Lua 5.1
RUN apt-get update && apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    liblua5.1-0-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src

# Copy proyek
COPY . .

# Build aplikasi
RUN if ls *.csproj 1> /dev/null 2>&1; then \
        dotnet restore && \
        dotnet build -c Release -o /app/build && \
        dotnet publish -c Release -o /app/publish; \
    else \
        echo "No .csproj file found. Skipping .NET build."; \
    fi

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:3.1 AS runtime

# Install Lua 5.1 runtime
RUN apt-get update && apt-get install -y \
    lua5.1 \
    liblua5.1-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=build /app/publish .

# Environment untuk Render
ENV DOTNET_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

EXPOSE 8080

# Entry point (sesuaikan dengan proyek Anda)
ENTRYPOINT ["dotnet", "Ironbrew3.dll"]# Copy dari build stage
COPY --from=build /app/publish .

# Set environment variable untuk Discord Bot
ENV DOTNET_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080

# Expose port untuk Render
EXPOSE 8080

# Command untuk menjalankan bot Discord
# Sesuaikan dengan entry point aplikasi Anda
# CMD ["dotnet", "Ironbrew3.dll"]  # Jika langsung .NET app
# Atau jika menggunakan script startup khusus:
CMD ["bash", "-c", "dotnet Ironbrew3.dll || echo 'Aplikasi berhenti'"]
