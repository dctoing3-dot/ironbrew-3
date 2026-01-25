FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y wget curl gnupg ca-certificates tree

RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1

WORKDIR /app
COPY . .

# Debug 1: Struktur folder
RUN echo "=== STRUKTUR FOLDER ===" && \
    find /app -type f -name "*.cs" | head -50

# Debug 2: Isi semua file .cs di IronBrew2
RUN echo "=== ISI SEMUA FILE .CS ===" && \
    for f in $(find /app/IronBrew2 -name "*.cs" -type f); do \
        echo ""; \
        echo "========== FILE: $f =========="; \
        cat "$f" | head -100; \
    done

# Debug 3: Cari public class dan public method
RUN echo "=== PUBLIC CLASS/METHOD ===" && \
    grep -rn "public" /app/IronBrew2/*.cs 2>/dev/null || \
    grep -rn "public" /app/IronBrew2/**/*.cs 2>/dev/null || \
    echo "Tidak ditemukan di root, cari di subfolder..."

# Debug 4: List semua folder di IronBrew2
RUN echo "=== FOLDER DI IRONBREW2 ===" && \
    ls -la /app/IronBrew2/

# Debug 5: Cari file dengan kata "obfuscat" (case insensitive)
RUN echo "=== FILE DENGAN KATA OBFUSCAT ===" && \
    grep -ril "obfuscat" /app/IronBrew2/ || echo "Tidak ditemukan"

# Stop untuk baca log
RUN echo "=== DEBUG SELESAI - LIHAT LOG DI ATAS ===" && exit 1
