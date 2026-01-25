FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget curl gnupg ca-certificates

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1

WORKDIR /app
COPY . .

# Lihat isi Program.cs
RUN echo "=== ISI PROGRAM.CS ===" && cat /app/IronBrew2/Program.cs

# Lihat isi Obfuscator.cs (jika ada di root)
RUN echo "=== ISI OBFUSCATOR.CS ===" && \
    cat /app/IronBrew2/Obfuscator.cs 2>/dev/null || \
    echo "Tidak ada di root, cek subfolder..."

# Lihat file di folder Obfuscator
RUN echo "=== FILE DI FOLDER OBFUSCATOR ===" && \
    ls -la /app/IronBrew2/Obfuscator/

# Lihat Generator.cs (VM Generation)
RUN echo "=== ISI GENERATOR.CS ===" && \
    cat "/app/IronBrew2/Obfuscator/VM Generation/Generator.cs" | head -80

# Cari semua "public static" method
RUN echo "=== SEMUA PUBLIC STATIC METHOD ===" && \
    grep -rn "public static" /app/IronBrew2/*.cs /app/IronBrew2/**/*.cs 2>/dev/null | head -50

# Stop
RUN echo "=== SELESAI ===" && exit 1
