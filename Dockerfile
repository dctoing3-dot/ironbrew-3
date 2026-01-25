# Gunakan image .NET 3.0 SDK untuk build
FROM mcr.microsoft.com/dotnet/sdk:3.0 AS build

# Install Lua 5.1 untuk dependency
RUN apt-get update && apt-get install -y \
    lua5.1 \
    lua5.1-dev \
    liblua5.1-0-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /src

# Copy file proyek dan restore dependencies
COPY *.sln .
COPY *.csproj ./
RUN dotnet restore

# Copy semua file dan build
COPY . .
RUN dotnet build -c Release -o /app/build

# Publish aplikasi
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/runtime:3.0 AS runtime

# Install Lua 5.1 di runtime
RUN apt-get update && apt-get install -y \
    lua5.1 \
    liblua5.1-0 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy dari build stage
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
