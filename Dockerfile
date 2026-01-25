FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget curl gnupg ca-certificates

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1

WORKDIR /app
COPY . .

# Lihat SEMUA isi Program.cs
RUN echo "=== ISI LENGKAP PROGRAM.CS ===" && cat /app/IronBrew2/Program.cs

# Cari file ObfuscationSettings
RUN echo "=== CARI OBFUSCATIONSETTINGS ===" && \
    grep -rn "class ObfuscationSettings" /app/IronBrew2/ || \
    grep -rn "ObfuscationSettings" /app/IronBrew2/*.cs | head -20

# Cari semua namespace
RUN echo "=== SEMUA NAMESPACE ===" && \
    grep -rn "^namespace" /app/IronBrew2/*.cs /app/IronBrew2/**/*.cs 2>/dev/null | head -30

# Cari file dengan Settings
RUN echo "=== FILE DENGAN SETTINGS ===" && \
    find /app/IronBrew2 -name "*Settings*" -o -name "*Context*" | head -20

# Stop
RUN echo "=== SELESAI ===" && exit 1
