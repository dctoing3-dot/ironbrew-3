# Gunakan Ubuntu 20.04 
FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget curl gnupg ca-certificates tree \
    && rm -rf /var/lib/apt/lists/*

# Install .NET Core 3.1
RUN wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb \
    && dpkg -i packages-microsoft-prod.deb \
    && apt-get update \
    && apt-get install -y dotnet-sdk-3.1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy semua file
COPY . .

# ============ DEBUG: Lihat struktur folder ============
RUN echo "========================================" && \
    echo "=== STRUKTUR FOLDER /app ===" && \
    echo "========================================" && \
    tree -L 3 /app || find /app -maxdepth 3 -type f | head -100

# ============ DEBUG: Lihat semua file .cs di IronBrew2 ============
RUN echo "========================================" && \
    echo "=== FILE .CS DI IRONBREW2 ===" && \
    echo "========================================" && \
    find /app -name "*.cs" -type f | head -50

# ============ DEBUG: Lihat isi file utama (cari class/method) ============
RUN echo "========================================" && \
    echo "=== ISI FILE OBFUSCATOR (jika ada) ===" && \
    echo "========================================" && \
    (cat /app/IronBrew2/Obfuscator.cs 2>/dev/null || echo "File Obfuscator.cs tidak ditemukan")

RUN echo "========================================" && \
    echo "=== ISI FILE PROGRAM.CS (jika ada) ===" && \
    echo "========================================" && \
    (cat /app/IronBrew2/Program.cs 2>/dev/null || echo "File Program.cs tidak ditemukan")

# ============ DEBUG: Cari semua public class ============
RUN echo "========================================" && \
    echo "=== SEMUA PUBLIC CLASS DI IRONBREW2 ===" && \
    echo "========================================" && \
    grep -rn "public class\|public static class" /app/IronBrew2/*.cs 2>/dev/null | head -30 || echo "Tidak ditemukan"

# ============ DEBUG: Cari method yang mungkin untuk obfuscate ============
RUN echo "========================================" && \
    echo "=== SEMUA PUBLIC METHOD ===" && \
    echo "========================================" && \
    grep -rn "public static\|public void\|public string" /app/IronBrew2/*.cs 2>/dev/null | head -50 || echo "Tidak ditemukan"

# ============ DEBUG: Build IronBrew2 dan lihat DLL ============
RUN echo "========================================" && \
    echo "=== BUILD IRONBREW2 ===" && \
    echo "========================================" && \
    cd /app/IronBrew2 && dotnet restore && dotnet build -c Release && \
    echo "Build sukses!" && \
    ls -la /app/IronBrew2/bin/Release/netcoreapp3.1/

# ============ DEBUG: Lihat namespace dan types di DLL ============
RUN echo "========================================" && \
    echo "=== NAMESPACE/TYPES DI DLL ===" && \
    echo "========================================" && \
    dotnet /app/IronBrew2/bin/Release/netcoreapp3.1/IronBrew2.dll --help 2>&1 || echo "(DLL tidak bisa dijalankan langsung, ini normal untuk library)"

# Stop disini untuk debug
RUN echo "========================================" && \
    echo "=== DEBUG SELESAI ===" && \
    echo "=== Lihat log di atas untuk struktur repo ===" && \
    echo "========================================" && \
    exit 1                Environment.Exit(1); \n\
            } \n\
            \n\
            try \n\
            { \n\
                string inputPath = args[0]; \n\
                string outputPath = args[1]; \n\
                \n\
                Console.WriteLine("Reading: " + inputPath); \n\
                string luaCode = File.ReadAllText(inputPath); \n\
                \n\
                Console.WriteLine("Obfuscating..."); \n\
                string obfuscated = IronBrew2.Obfuscator.Obfuscate(luaCode); \n\
                \n\
                Console.WriteLine("Writing: " + outputPath); \n\
                File.WriteAllText(outputPath, obfuscated); \n\
                \n\
                Console.WriteLine("Done!"); \n\
            } \n\
            catch (Exception ex) \n\
            { \n\
                Console.WriteLine("Error: " + ex.Message); \n\
                Console.WriteLine(ex.StackTrace); \n\
                Environment.Exit(1); \n\
            } \n\
        } \n\
    } \n\
}' > /app/CLI/Program.cs

# Build CLI wrapper
RUN cd /app/CLI && dotnet build -c Release

# Buat package.json untuk Discord bot
RUN echo '{\
  "name": "ironbrew3-discord-bot",\
  "version": "1.0.0",\
  "main": "index.js",\
  "dependencies": {\
    "discord.js": "^14.14.1",\
    "dotenv": "^16.3.1"\
  }\
}' > /app/package.json

# Install npm packages
RUN npm install

# Buat Discord bot (index.js)
RUN echo 'const { Client, GatewayIntentBits, REST, Routes, SlashCommandBuilder, AttachmentBuilder } = require("discord.js");\n\
const { exec } = require("child_process");\n\
const fs = require("fs");\n\
const http = require("http");\n\
\n\
const client = new Client({\n\
    intents: [\n\
        GatewayIntentBits.Guilds,\n\
        GatewayIntentBits.GuildMessages,\n\
        GatewayIntentBits.MessageContent\n\
    ]\n\
});\n\
\n\
client.once("ready", async () => {\n\
    console.log(`Bot is online as ${client.user.tag}`);\n\
    \n\
    const commands = [\n\
        new SlashCommandBuilder()\n\
            .setName("obfuscate")\n\
            .setDescription("Obfuscate Lua script")\n\
            .addAttachmentOption(opt => opt.setName("file").setDescription("Lua file").setRequired(true)),\n\
        new SlashCommandBuilder()\n\
            .setName("ping")\n\
            .setDescription("Check bot latency")\n\
    ];\n\
    \n\
    const rest = new REST({ version: "10" }).setToken(process.env.TOKEN);\n\
    try {\n\
        await rest.put(Routes.applicationCommands(client.user.id), { body: commands });\n\
        console.log("Slash commands registered!");\n\
    } catch (error) {\n\
        console.error("Error registering commands:", error);\n\
    }\n\
});\n\
\n\
client.on("interactionCreate", async interaction => {\n\
    if (!interaction.isChatInputCommand()) return;\n\
    \n\
    if (interaction.commandName === "ping") {\n\
        await interaction.reply(`Pong! ${client.ws.ping}ms`);\n\
    }\n\
    \n\
    if (interaction.commandName === "obfuscate") {\n\
        await interaction.deferReply();\n\
        const attachment = interaction.options.getAttachment("file");\n\
        \n\
        if (!attachment.name.endsWith(".lua")) {\n\
            return interaction.editReply("Please upload a .lua file!");\n\
        }\n\
        \n\
        try {\n\
            const response = await fetch(attachment.url);\n\
            const luaCode = await response.text();\n\
            const inputPath = `/tmp/input_${Date.now()}.lua`;\n\
            const outputPath = `/tmp/output_${Date.now()}.lua`;\n\
            \n\
            fs.writeFileSync(inputPath, luaCode);\n\
            \n\
            exec(`dotnet /app/CLI/bin/Release/netcoreapp3.1/CLI.dll "${inputPath}" "${outputPath}"`,\n\
                { timeout: 120000 },\n\
                async (error, stdout, stderr) => {\n\
                    console.log("STDOUT:", stdout);\n\
                    console.log("STDERR:", stderr);\n\
                    \n\
                    if (fs.existsSync(outputPath)) {\n\
                        const file = new AttachmentBuilder(outputPath, { name: "obfuscated.lua" });\n\
                        await interaction.editReply({ content: "Obfuscation complete!", files: [file] });\n\
                        fs.unlinkSync(inputPath);\n\
                        fs.unlinkSync(outputPath);\n\
                    } else {\n\
                        const errMsg = (stderr || stdout || error?.message || "Unknown error").slice(-1500);\n\
                        await interaction.editReply("Error:\\n```\\n" + errMsg + "\\n```");\n\
                        if (fs.existsSync(inputPath)) fs.unlinkSync(inputPath);\n\
                    }\n\
                }\n\
            );\n\
        } catch (error) {\n\
            await interaction.editReply(`Error: ${error.message}`);\n\
        }\n\
    }\n\
});\n\
\n\
const server = http.createServer((req, res) => {\n\
    res.writeHead(200, { "Content-Type": "text/plain" });\n\
    res.end("OK");\n\
});\n\
server.listen(process.env.PORT || 8080, () => {\n\
    console.log(`Health server on port ${process.env.PORT || 8080}`);\n\
});\n\
\n\
client.login(process.env.TOKEN);' > /app/index.js

# Buat startup script
RUN echo '#!/bin/bash\n\
echo "=== Ironbrew 3 Discord Bot ==="\n\
echo "Starting at: $(date)"\n\
\n\
if [ -z "$TOKEN" ]; then\n\
    echo "ERROR: TOKEN not set!"\n\
    exit 1\n\
fi\n\
\n\
echo "Starting bot..."\n\
cd /app\n\
node index.js' > /app/start.sh && chmod +x /app/start.sh

EXPOSE 8080

CMD ["/app/start.sh"]
